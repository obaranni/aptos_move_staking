#[test_only]
module staking_admin::staking_tests {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin;
    use coin_creator::liq::{Self, LIQCoin};

    use staking_admin::staking;

    #[test]
    public fun test_stake_and_unstake() {
        let coin_creator_acc = account::create_account_for_test(@coin_creator);
        let staking_admin_acc = account::create_account_for_test(@staking_admin);
        let alice_acc = account::create_account_for_test(@0x10);
        let bob_acc = account::create_account_for_test(@0x11);

        // create coin
        liq::initialize(&coin_creator_acc);

        // mint coins for alice and bob
        let coins = liq::mint(&coin_creator_acc, 150);
        coin::register<LIQCoin>(&alice_acc);
        coin::deposit<LIQCoin>(signer::address_of(&alice_acc), coins);
        let coins = liq::mint(&coin_creator_acc, 40);
        coin::register<LIQCoin>(&bob_acc);
        coin::deposit<LIQCoin>(signer::address_of(&bob_acc), coins);

        // check balances
        assert!(coin::balance<LIQCoin>(signer::address_of(&alice_acc)) == 150, 1);
        assert!(coin::balance<LIQCoin>(signer::address_of(&bob_acc)) == 40, 1);

        // initialize staking pool
        staking::initialize<LIQCoin>(&staking_admin_acc);

        // check empty balances
        assert!(staking::get_total_stake<LIQCoin>() == 0, 1);
        assert!(staking::get_user_stake<LIQCoin>(signer::address_of(&alice_acc)) == 0, 1);
        assert!(staking::get_user_stake<LIQCoin>(signer::address_of(&bob_acc)) == 0, 1);

        // stake from alice
        let coins = coin::withdraw<LIQCoin>(&alice_acc, 33);
        staking::stake<LIQCoin>(&alice_acc, coins);
        assert!(coin::balance<LIQCoin>(signer::address_of(&alice_acc)) == 117, 1);
        assert!(staking::get_user_stake<LIQCoin>(signer::address_of(&alice_acc)) == 33, 1);
        assert!(staking::get_total_stake<LIQCoin>() == 33, 1);

        // stake from bob
        let coins = coin::withdraw<LIQCoin>(&bob_acc, 40);
        staking::stake<LIQCoin>(&bob_acc, coins);
        assert!(coin::balance<LIQCoin>(signer::address_of(&bob_acc)) == 0, 1);
        assert!(staking::get_user_stake<LIQCoin>(signer::address_of(&bob_acc)) == 40, 1);
        assert!(staking::get_total_stake<LIQCoin>() == 73, 1);

        // stake more from alice
        let coins = coin::withdraw<LIQCoin>(&alice_acc, 33);
        staking::stake<LIQCoin>(&alice_acc, coins);
        assert!(coin::balance<LIQCoin>(signer::address_of(&alice_acc)) == 84, 1);
        assert!(staking::get_user_stake<LIQCoin>(signer::address_of(&alice_acc)) == 66, 1);
        assert!(staking::get_total_stake<LIQCoin>() == 106, 1);

        // unstake some from alice
        let coins = staking::unstake<LIQCoin>(&alice_acc, 16);
        coin::deposit<LIQCoin>(signer::address_of(&alice_acc), coins);
        assert!(coin::balance<LIQCoin>(signer::address_of(&alice_acc)) == 100, 1);
        assert!(staking::get_user_stake<LIQCoin>(signer::address_of(&alice_acc)) == 50, 1);
        assert!(staking::get_total_stake<LIQCoin>() == 90, 1);

        // unstake all from bob
        let coins = staking::unstake<LIQCoin>(&bob_acc, 40);
        coin::deposit<LIQCoin>(signer::address_of(&bob_acc), coins);
        assert!(coin::balance<LIQCoin>(signer::address_of(&bob_acc)) == 40, 1);
        assert!(staking::get_user_stake<LIQCoin>(signer::address_of(&bob_acc)) == 0, 1);
        assert!(staking::get_total_stake<LIQCoin>() == 50, 1);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_stake_fails_if_pool_does_not_exist() {
        let coin_creator_acc = account::create_account_for_test(@coin_creator);
        let alice_acc = account::create_account_for_test(@0x10);

        // create coin
        liq::initialize(&coin_creator_acc);

        // mint coins for alice
        let coins = liq::mint(&coin_creator_acc, 150);
        coin::register<LIQCoin>(&alice_acc);
        coin::deposit<LIQCoin>(signer::address_of(&alice_acc), coins);
        assert!(coin::balance<LIQCoin>(signer::address_of(&alice_acc)) == 150, 1);

        // stake from alice
        let coins = coin::withdraw<LIQCoin>(&alice_acc, 33);
        staking::stake<LIQCoin>(&alice_acc, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_unstake_fails_if_pool_does_not_exist() {
        let alice_acc = account::create_account_for_test(@0x10);

        // unstake from alice
        let coins = staking::unstake<LIQCoin>(&alice_acc, 100);
        coin::deposit<LIQCoin>(signer::address_of(&alice_acc), coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_total_stake_fails_if_pool_does_not_exist() {
        staking::get_total_stake<LIQCoin>();
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_user_stake_fails_if_pool_does_not_exist() {
        let alice_acc = account::create_account_for_test(@0x10);

        staking::get_user_stake<LIQCoin>(signer::address_of(&alice_acc));
    }

    #[test]
    #[expected_failure(abort_code = 101 /* ERR_POOL_ALREADY_EXISTS */)]
    public fun test_initialize_fails_if_pool_already_exists() {
        let staking_admin_acc = account::create_account_for_test(@staking_admin);

        // initialize staking pool twice
        staking::initialize<LIQCoin>(&staking_admin_acc);
        staking::initialize<LIQCoin>(&staking_admin_acc);
    }

    #[test]
    #[expected_failure(abort_code = 102 /* ERR_NO_STAKE */)]
    public fun test_unstake_fails_if_stake_not_exists() {
        let staking_admin_acc = account::create_account_for_test(@staking_admin);
        let alice_acc = account::create_account_for_test(@0x10);

        // initialize staking pool
        staking::initialize<LIQCoin>(&staking_admin_acc);

        // unstake from alice
        let coins = staking::unstake<LIQCoin>(&alice_acc, 40);
        coin::deposit<LIQCoin>(signer::address_of(&alice_acc), coins);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NOT_ENOUGHT_BALANCE */)]
    public fun test_unstake_fails_if_not_enough_balance() {
        let coin_creator_acc = account::create_account_for_test(@coin_creator);
        let staking_admin_acc = account::create_account_for_test(@staking_admin);
        let alice_acc = account::create_account_for_test(@0x10);

        // create coin
        liq::initialize(&coin_creator_acc);

        // mint coins for alice
        let coins = liq::mint(&coin_creator_acc, 150);
        coin::register<LIQCoin>(&alice_acc);
        coin::deposit<LIQCoin>(signer::address_of(&alice_acc), coins);
        assert!(coin::balance<LIQCoin>(signer::address_of(&alice_acc)) == 150, 1);

        // initialize staking pool
        staking::initialize<LIQCoin>(&staking_admin_acc);

        // stake from alice
        let coins = coin::withdraw<LIQCoin>(&alice_acc, 150);
        staking::stake<LIQCoin>(&alice_acc, coins);
        assert!(coin::balance<LIQCoin>(signer::address_of(&alice_acc)) == 0, 1);
        assert!(staking::get_user_stake<LIQCoin>(signer::address_of(&alice_acc)) == 150, 1);

        // unstake more than staked from alice
        let coins = staking::unstake<LIQCoin>(&alice_acc, 151);
        coin::deposit<LIQCoin>(signer::address_of(&alice_acc), coins);
    }
}
