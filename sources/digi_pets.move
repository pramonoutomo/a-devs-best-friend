/* 
    Relive the 90's with a blockchain twist by implementing your own, on-chain digital pets!

    Key Concepts: 
        - Token v2 non-fungible tokens
        - Token v2 fungible tokens
        - Aptos coin
        - String utilities
*/
module overmind::digi_pets {

    //==============================================================================================
    // Dependencies
    //==============================================================================================

    use std::vector;
    use std::object;
    use std::signer;
    use std::signer::address_of;
    use std::string_utils;
    use aptos_framework::coin;
    use aptos_framework::option;
    use aptos_framework::timestamp;
    use aptos_token_objects::token;
    use std::string::{Self, String};
    use aptos_std::simple_map;
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::aptos_coin::{AptosCoin};
    use aptos_framework::event::{Self, EventHandle, emit_event};
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::account::{Self, SignerCapability, create_resource_account};
    use aptos_framework::managed_coin::register;
    use aptos_framework::object::{address_to_object, object_address, address_from_constructor_ref, generate_extend_ref};
    use aptos_framework::resource_account;
    use aptos_framework::timestamp::now_seconds;
    use aptos_token_objects::collection::create_unlimited_collection;
    use aptos_token_objects::royalty::generate_mutator_ref;
    use aptos_token_objects::token::{create_named_token, create_token_address, royalty};

    #[test_only]
    use aptos_token_objects::royalty;
    #[test_only]
    use aptos_framework::aptos_coin::{Self};

    //==============================================================================================
    // Constants - DO NOT MODIFY
    //==============================================================================================

    // Seed for resource account creation
    const SEED: vector<u8> = b"digi-pets";

    // constant for math
    const DAY_IN_SECONDS: u64 = 86400;

    // Types of digi pets
    const PET_TYPES: vector<vector<u8>> = vector<vector<u8>>[
        b"Dog", 
        b"Cat", 
        b"Snake", 
        b"Monkey"
    ];
    
    // Pet toys
    const TOY_FOR_DOG: vector<u8> = b"Chew toy";
    const TOY_FOR_CAT: vector<u8> = b"Yarn ball";
    const TOY_FOR_SNAKE: vector<u8> = b"Teddy bear";
    const TOY_FOR_MONKEY: vector<u8> = b"Beach ball";

    // Digi-pet collection information
    const DIGI_PET_COLLECTION_NAME: vector<u8> = b"Digi-Pets collection name";
    const DIGI_PET_COLLECTION_DESCRIPTION: vector<u8> = b"Digi-Pets collection description";
    const DIGI_PET_COLLECTION_URI: vector<u8> = b"Digi-Pets collection uri";

    // Digi-pet token information
    const DIGI_PET_TOKEN_DESCRIPTION: vector<u8> = b"Digi-Pets token description";
    const DIGI_PET_TOKEN_URI: vector<u8> = b"Digi-Pets token uri";

    // Digi-pet accessory collection information
    const DIGI_PET_ACCESSORY_COLLECTION_NAME: vector<u8> = b"Digi-Pets accessory collection name";
    const DIGI_PET_ACCESSORY_COLLECTION_DESCRIPTION: vector<u8> = b"Digi-Pets accessory collection description";
    const DIGI_PET_ACCESSORY_COLLECTION_URI: vector<u8> = b"Digi-Pets accessory collection uri";

    // property names for digi-pet token properties
    const PROPERTY_KEY_PET_NAME: vector<u8> = b"pet_name";
    const PROPERTY_KEY_PET_TYPE: vector<u8> = b"pet_type";
    const PROPERTY_KEY_PET_HEALTH: vector<u8> = b"pet_health";
    const PROPERTY_KEY_PET_HAPPINESS: vector<u8> = b"pet_happiness";
    const PROPERTY_KEY_PET_BIRTHDAY_TIMESTAMP_SECONDS: vector<u8> = b"pet_birthday";
    const PROPERTY_KEY_LAST_TIMESTAMP_FED: vector<u8> = b"last_timestamp_fed";
    const PROPERTY_KEY_LAST_TIMESTAMP_PLAYED_WITH: vector<u8> = b"last_timestamp_played_with";
    const PROPERTY_KEY_LAST_TIMESTAMP_UPDATED: vector<u8> = b"last_timestamp_updated";

    // Starting values for digi-pet token properties
    const STARTING_VALUE_PET_HEALTH: u64 = 100;
    const STARTING_VALUE_PET_HAPPINESS: u64 = 100;

    // Digi-pet food token information
    const FOOD_TOKEN_NAME: vector<u8> = b"food token name";
    const FOOD_TOKEN_DESCRIPTION: vector<u8> = b"food token description";
    const FOOD_TOKEN_URI: vector<u8> = b"food token uri";
    const FOOD_TOKEN_FUNGIBLE_ASSET_NAME: vector<u8> = b"food token fungible asset name";
    const FOOD_TOKEN_FUNGIBLE_ASSET_SYMBOL: vector<u8> = b"FOOD";
    const FOOD_TOKEN_ICON_URI: vector<u8> = b"food token icon uri";
    const FOOD_TOKEN_PROJECT_URI: vector<u8> = b"food token project uri";
    const FOOD_TOKEN_DECIMALS: u8 = 0;

    // Prices 
    const FOOD_TOKEN_PRICE: u64 = 5000000; // .05 APT
    const TOY_PRICE_APT: u64 = 100000000; // 1 APT

    // Starting value for toy
    const STARTING_TOY_DURABILITY: u64 = 50;

    //==============================================================================================
    // Error codes - DO NOT MODIFY
    //==============================================================================================

    const EInsufficientAptBalance: u64 = 0;
    const EInsufficientFoodBalance: u64 = 1;
    const ENotOwnerOfPet: u64 = 3;
    const EInvalidPetType: u64 = 4;

    //==============================================================================================
    // Module Structs - DO NOT MODIFY
    //==============================================================================================

    /* 
        Digi-pet NFT token type
    */
    struct DigiPetToken has key {
        // Used for editing the token data
        mutator_ref: token::MutatorRef,
        // Used for burning the token
        burn_ref: token::BurnRef,
        // USed for editing the token's property_map
        property_mutator_ref: property_map::MutatorRef, 
        // A list of toys for the digi-pet
        toys: vector<Toy>
    }

    /* 
        Information about a toy. Used for keeping the digi-pets happy
    */
    struct Toy has store, drop, copy {
        // name of the specific toy
        name: String,
        // how much happiness the toy can supply to the pet
        durability: u64
    }

    /* 
        struct for any fungible token for digi-pets
    */
    struct AccessoryToken has key {
        mutator_ref: property_map::MutatorRef,
        mint_ref: fungible_asset::MintRef,
        burn_ref: fungible_asset::BurnRef,
    }

    /* 
        Information to be used in the module
    */
    struct State has key {
        // signer cap of the module's resource account
        signer_cap: SignerCapability,
        // the number of pets adopted - used for pet name generation
        pet_count: u64, 
        // Events
        adopt_pet_events: EventHandle<AdoptPetEvent>, 
        feed_pet_events: EventHandle<FeedPetEvent>,
        play_with_pet_events: EventHandle<PlayWithPetEvent>,
        bury_pet_events: EventHandle<BuryPetEvent>,
    }

    //==============================================================================================
    // Event structs - DO NOT MODIFY
    //==============================================================================================

    /* 
        Event to be emitted when a pet is adopted
    */
    struct AdoptPetEvent has store, drop {
        // address of the account adopting the new pet
        adopter: address, 
        // name of the new pet
        pet_name: String, 
        // address of the pet
        pet: address,
        // type of pet
        pet_type: String
    }

    /* 
        Event to be emitted when a pet is fed
    */
    struct FeedPetEvent has store, drop {
        // address of the account that owns the pet
        owner: address, 
        // address of the pet
        pet: address
    }

    /* 
        Event to be emitted when a pet is played with
    */
    struct PlayWithPetEvent has store, drop {
        // address of the account that owns the pet
        owner: address, 
        // address of the pet
        pet: address
    }

    /* 
        Event to be emitted when a pet is buried
    */
    struct BuryPetEvent has store, drop {
        // address of the account that owns the pet
        owner: address, 
        // address of the pet
        pet: address
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /* 
        Initializes the module by creating a resource account, registering with AptosCoin, creating
        the token collectiions, and setting up the State resource.
        @param account - signer representing the module publisher
    */
    fun init_module(account: &signer) {
        // TODO: Create a resource account with the account signer and the `SEED` constant
        let (resource_account, resource_signer  ) = create_resource_account(account, SEED);
        // TODO: Register the resource account with AptosCoin
        register<AptosCoin>(&resource_account);
        // TODO: Create an NFT collection with an unlimied supply and the following aspects: 
        //          - name: DIGI_PET_COLLECTION_NAME
        //          - description: DIGI_PET_COLLECTION_DESCRIPTION
        //          - uri: DIGI_PET_COLLECTION_URI
        //          - royalty: no royalty
        collection::create_unlimited_collection(&resource_account,
            string::utf8(DIGI_PET_COLLECTION_NAME),
            string::utf8(DIGI_PET_COLLECTION_DESCRIPTION),
            option::none(),
            string::utf8(DIGI_PET_ACCESSORY_COLLECTION_URI));

        // TODO: Create an NFT collection with an unlimied supply and the following aspects: 
        //          - name: DIGI_PET_ACCESSORY_COLLECTION_NAME
        //          - description: DIGI_PET_ACCESSORY_COLLECTION_DESCRIPTION
        //          - uri: DIGI_PET_ACCESSORY_COLLECTION_URI
        //          - royalty: no royalty
        collection::create_unlimited_collection(&resource_account,
            string::utf8(DIGI_PET_ACCESSORY_COLLECTION_NAME),
            string::utf8(DIGI_PET_ACCESSORY_COLLECTION_DESCRIPTION),
            option::none(),
            string::utf8(DIGI_PET_ACCESSORY_COLLECTION_URI));

        // TODO: Create fungible token for digi pet food 
        // 
        // HINT: Use helper function - create_food_fungible_token
        create_food_token(&resource_account);

        // TODO: Create the State global resource and move it to the resource account
        let state = State {
            signer_cap: resource_signer,
            // the number of pets adopted - used for pet name generation
            pet_count: 0,
            // Events
            adopt_pet_events: account::new_event_handle<AdoptPetEvent>(&resource_account),
            feed_pet_events: account::new_event_handle<FeedPetEvent>(&resource_account),
            play_with_pet_events: account::new_event_handle<PlayWithPetEvent>(&resource_account),
            bury_pet_events: account::new_event_handle<BuryPetEvent>(&resource_account),
        };
        move_to<State>(&resource_account, state);
    }

    /* 
        Mints a new DigiPetToken for the adopter account
        @param adopter - signer representing the account adopting the new pet
        @param pet_name - name of the pet to be adopted
        @param pet_type_code - code which specifies the type of digi-pet that is being adopted
    */
    public entry fun adopt_pet(
        adopter: &signer,
        pet_name: String, 
        pet_type_code: u64
    ) acquires State {
        // TODO: Create the pet token's name based off the State's pet_count. Increment the pet 
        //          count as well.
        //
        // HINT: Use this formatting - "Pet #{}", where {} is the pet_count + 1
        let state = borrow_global_mut<State>(get_resource_account_address());
        let pet_count = state.pet_count;
        let pet_name = string_utils::format1(&b"Pet #{}", pet_count);

        // TODO: Create a new named token with the following aspects: 
        //          - collection name: DIGI_PET_COLLECTION_NAME
        //          - token description: DIGI_PET_TOKEN_DESCRIPTION
        //          - token name: Specified in above TODO
        //          - royalty: no royalty
        //          - uri: DIGI_PET_TOKEN_URI
        let named_token = create_named_token(
            adopter,
            pet_name,
            string::utf8(DIGI_PET_COLLECTION_NAME),
            string::utf8(DIGI_PET_TOKEN_DESCRIPTION),
            option::none(),
            string::utf8(DIGI_PET_TOKEN_URI),
        );
        // let toke_mut_ref = generate_mutator_ref(&named_token);


        // let token_address = get_pet_token_address_with_token_name(string::utf8(DIGI_PET_TOKEN_DESCRIPTION));
        //     //         &resource_account_address,
        //     //         &string::utf8(b"Digi-Pets collection name"),
        //     //         &string::utf8(b"Pet #1: \"max\"")
        //     //     );
        // let pet_token_object = object::address_to_object<token::Token>(token_address);
        // // generate_extend_ref(named_token);
        // let mutator_ref = generate_mutator_ref(generate_extend_ref(&named_token));


        // TODO: Transfer the token to the adopter account
        coin::transfer<AccessoryToken>(adopter, address_of(adopter), 1);

        // TODO: Create the property_map for the new token with the following properties: 
        //          - PROPERTY_KEY_PET_NAME: the name of the pet (same as token name)
        //          - PROPERTY_KEY_PET_TYPE: the type of pet (string)
        //          - PROPERTY_KEY_PET_HEALTH: the health level of the pet (use STARTING_VALUE_PET_HEALTH)
        //          - PROPERTY_KEY_PET_HAPPINESS: the happiness level of the pet (use STARTING_VALUE_PET_HAPPINESS)
        //          - PROPERTY_KEY_PET_BIRTHDAY_TIMESTAMP_SECONDS: the current timestamp
        //          - PROPERTY_KEY_LAST_TIMESTAMP_FED: the current timestamp
        //          - PROPERTY_KEY_LAST_TIMESTAMP_PLAYED_WITH: the current timestamp
        //          - PROPERTY_KEY_LAST_TIMESTAMP_UPDATED: the current timestamp
        // let property_map = simple_map::create();
        // simple_map::add(&mut property_map, PROPERTY_KEY_PET_NAME, pet_name);
        // simple_map::add(&mut property_map, PROPERTY_KEY_PET_TYPE, pet_type_code);
        // simple_map::add(&mut property_map, PROPERTY_KEY_PET_HEALTH, STARTING_VALUE_PET_HEALTH);
        // simple_map::add(&mut property_map, PROPERTY_KEY_PET_HAPPINESS, STARTING_VALUE_PET_HAPPINESS);
        // simple_map::add(&mut property_map, PROPERTY_KEY_PET_BIRTHDAY_TIMESTAMP_SECONDS, now_seconds());
        // simple_map::add(&mut property_map, PROPERTY_KEY_LAST_TIMESTAMP_FED, now_seconds());
        // simple_map::add(&mut property_map, PROPERTY_KEY_LAST_TIMESTAMP_PLAYED_WITH, now_seconds());
        // simple_map::add(&mut property_map, PROPERTY_KEY_LAST_TIMESTAMP_UPDATED, now_seconds());

        // let value = property_map::read_string(&pet_token_object, &string::utf8(b"pet_name"));

        let map = property_map::prepare_input(vector::empty(), vector::empty(), vector::empty());
        property_map::init(&named_token, map);
        let mutator_ref = property_map::generate_mutator_ref(&named_token);

        property_map::add_typed(&mutator_ref, string::utf8(PROPERTY_KEY_PET_NAME), pet_name);
        // address_from_constructor_ref()
        // coin::n


        // TODO: Create the DigiPetToken object and move it to the new token object signer
        // let digi_pet_token = DigiPetToken {
        //     mutator_ref: token::generate_mutator_ref(&named_token),
        //     burn_ref: token::generate_burn_ref(&named_token),
        //     property_mutator_ref: generate_mutator_ref(property_map),
        //     toys: vector::empty(),
        // };

        // TODO: Emit a new AdoptPetEvent
        emit_event(&mut state.adopt_pet_events, AdoptPetEvent {
            adopter: address_of(adopter),
            pet_name,
            pet: address_from_constructor_ref(&named_token),
            pet_type: string::utf8(*vector::borrow(&PET_TYPES, pet_type_code)),
        });
    }

    /* 
        Mints food tokens in exchange for apt
        @param buyer - signer representing the buyer of the food tokens
        @param amount - amount of food tokens to purchase
    */
    public entry fun buy_pet_food(buyer: &signer, amount: u64) acquires AccessoryToken {
        // TODO: Ensure the buyer has enough APT
        //
        // HINT: 
        //      - Use check_if_user_has_enough_apt function below
        //      - Use `amount` and FOOD_TOKEN_PRICE to calculate the correct amount of APT to check
        check_if_user_has_enough_apt(address_of(buyer), amount);

        // let aptos_token = borrow_global_mut<AptosCoin>(address_of(buyer));
        // assert!(coin::balance<AccessoryToken>(address_of(buyer)) > amount * FOOD_TOKEN_PRICE, EInsufficientAptBalance);

        // TODO: Transfer the correct amount of APT from the buyer to the module's resource account
        //
        // HINT: Use `amount` and FOOD_TOKEN_PRICE to calculate the correct amount of APT to transfer
        coin::transfer<AptosCoin>(buyer, get_resource_account_address(), amount * FOOD_TOKEN_PRICE);

        // TODO: Mint `amount` of food tokens to the buyer
        //
        // HINT: Use the mint_fungible_token_internal function
        mint_fungible_token_internal(food_token_address(), amount, address_of(buyer));
        
    }

    /* 
        Creates a new Toy resource for the buyer's pet
        @param buyer - signer representing the account that is buying a toy for their pet
        @param pet - address of the pet to buy a toy for
    */
    public entry fun buy_pet_toy(buyer: &signer, pet: address) acquires DigiPetToken {
        // TODO: Ensure the buyer owns the pet
        //
        // HINT: 
        //      - Use check_if_user_owns_pet function below
        check_if_user_owns_pet(address_of(buyer), pet);

        // TODO: Ensure the buyer has enough APT
        //
        // HINT: 
        //      - Use check_if_user_has_enough_apt function below
        //      - Use TOY_PRICE_APT as the amount of APT to transfer
        check_if_user_has_enough_apt(address_of(buyer), TOY_PRICE_APT);

        // TODO: Transfer the correct amount of APT from the buyer to the module's resource account
        //
        // HINT: Use TOY_PRICE_APT as the amount of APT to transfer
        coin::transfer<AptosCoin>(buyer, get_resource_account_address(), TOY_PRICE_APT);

        // TODO: Get the correct toy name based on the token's pet_type property
        //
        // HINT: Use the get_toy_name function
        let pet_token= borrow_global_mut<DigiPetToken>(address_of(buyer));
        let pet_token_object = object::address_to_object<token::Token>(pet);

        let pet_name = property_map::read_string(&pet_token_object, &string::utf8(PROPERTY_KEY_PET_NAME));

        let toy_name = get_toy_name(pet_name);

        // TODO: Create a new toy object with the correct name and durability and push it to the 
        //          pet's toy list
        //
        // HINT: Use STARTING_TOY_DURABILITY for the durability
        let toy = Toy {
            name: toy_name,
            durability: STARTING_TOY_DURABILITY,
        };
        vector::push_back(&mut pet_token.toys, toy);
        
    }

    /* 
        Burn food tokens to increase the health of a pet
        @param owner - signer representing the owner of the pet
        @param pet_to_feed - address of the pet to be fed
        @param amount_to_feed - amount of food tokens to feed the pet
    */
    public entry fun feed_pet(
        owner: &signer,
        pet_to_feed: address,
        amount_to_feed: u64
    ) acquires State, DigiPetToken, AccessoryToken {
        // TODO: Ensure the owner owns the pet
        //
        // HINT: 
        //      - Use check_if_user_owns_pet function below
        check_if_user_owns_pet(address_of(owner), pet_to_feed);
        
        // TODO: Ensure the buyer has enough food to feed the pet
        //
        // HINT: 
        //      - Use check_if_user_has_enough_food function below
        check_if_user_has_enough_food(address_of(owner), amount_to_feed);

        // TODO: Update the pet status. If the pet is dead, call bury_pet and return
        //
        // HINT: Use the update_pet_stats function

        let dead = update_pet_stats(pet_to_feed);


        // TODO: Burn the correct amount of food tokens
        // 
        // HINT: Use the burn_fungible_token_internal function
        if (dead) {
            burn_fungible_token_internal(owner, pet_to_feed, amount_to_feed);
        };

        // TODO: Add the amount of food to the pet's PROPERTY_KEY_PET_HEALTH
        let tokens = borrow_global_mut<DigiPetToken>(address_of(owner));
        let pet_token_object = object::address_to_object<token::Token>(pet_to_feed);
        let pet_health = property_map::read_u64(&pet_token_object, &string::utf8(PROPERTY_KEY_PET_HEALTH));
        property_map::update_typed(&tokens.property_mutator_ref, &string::utf8(PROPERTY_KEY_PET_HEALTH), pet_health + amount_to_feed);


        // TODO: Update the pet's PROPERTY_KEY_LAST_TIMESTAMP_FED
        property_map::update_typed(&tokens.property_mutator_ref, &string::utf8(PROPERTY_KEY_LAST_TIMESTAMP_FED), now_seconds());

        // TODO: Emit a new FeedPetEvent
        let state = borrow_global_mut<State>(get_resource_account_address());
        emit_event(&mut state.feed_pet_events, FeedPetEvent {
            owner: address_of(owner),
            pet: pet_to_feed,
        });
    }

    /* 
        Reset the pet's happiness
        @param owner - signer representing the owner of the pet
        @param pet_to_play_with - address of the pet to be played with
    */
    public entry fun play_with_pet(owner: &signer, pet_to_play_with: address) acquires State, DigiPetToken {
        // TODO: Ensure the owner owns the pet
        //
        // HINT: 
        //      - Use check_if_user_owns_pet function below
        check_if_user_owns_pet(address_of(owner), pet_to_play_with);

        // TODO: Update the pet status. If the pet is dead, call bury_pet and return
        //
        // HINT: Use the update_pet_stats function
        let dead = update_pet_stats(pet_to_play_with);
        if (dead) {
            bury_pet(pet_to_play_with);
        };

        // TODO: Set the pet's PROPERTY_KEY_PET_HAPPINESS to 150
        let tokens = borrow_global_mut<DigiPetToken>(address_of(owner));
        property_map::update_typed(&tokens.property_mutator_ref, &string::utf8(PROPERTY_KEY_PET_HAPPINESS), 150);


        // TODO: Update the pet's PROPERTY_KEY_LAST_TIMESTAMP_PLAYED_WITH
        property_map::update_typed(&tokens.property_mutator_ref, &string::utf8(PROPERTY_KEY_LAST_TIMESTAMP_PLAYED_WITH), now_seconds());

        // TODO: Emit a new PlayWithPetEvent
        let state = borrow_global_mut<State>(get_resource_account_address());
        emit_event(&mut state.play_with_pet_events, PlayWithPetEvent {
            owner: address_of(owner),
            // address of the pet
            pet: pet_to_play_with,
        });
        
    }

    /* 
        Update's a pet's stats. Will bury the pet if the pet has died. A pet can be updated by 
        anyone.
        @param pet - address of the pet to be updated
    */
    public entry fun update_pet_stats_entry(pet: address) acquires State, DigiPetToken {
        // TODO: Update the pet status. If the pet is dead, call bury_pet and return
        //
        // HINT: Use the update_pet_stats function
        let dead = update_pet_stats(pet);
        if (dead) {
            bury_pet(pet);
        };

    }

    //==============================================================================================
    // Helper functions
    //==============================================================================================

    /* 
        Fetches the toy name for the given type of pet
        @param pet_type - string representing the type of pet
        @return - the name of the toy for the given pet type
    */
    inline fun get_toy_name(pet_type: String): String {
        // TODO: Return the correct toy name based on the type of pet: 
        //          - "Dog": TOY_FOR_DOG
        //          - "Cat": TOY_FOR_CAT
        //          - "Snake": TOY_FOR_SNAKE
        //          - "Monkey": TOY_FOR_MONKEY
        //          - "Monkey": TOY_FOR_MONKEY
        //
        // HINT: Abort with code: EInvalidPetType, if pet_type is not any of the above types
        if (pet_type == string::utf8(b"Dog")) {string::utf8(TOY_FOR_DOG)}
        else if (pet_type == string::utf8(b"Cat")) {string::utf8(TOY_FOR_CAT)}
        else if (pet_type == string::utf8(b"Snake")) {string::utf8(TOY_FOR_SNAKE)}
        else if (pet_type == string::utf8(b"Monkey")) {string::utf8(TOY_FOR_MONKEY)}
        else {abort(EInvalidPetType)}
    }

    /* 
        Update the pet's stats, and returns true if the pet is still alive and false otherwise.
        @param pet - address of the pet to update
        @return - true if the pet is still alive and false otherwise.
    */
    inline fun update_pet_stats(
        pet: address
    ): bool acquires AccessoryToken {
        // TODO: Fetch the PROPERTY_KEY_LAST_TIMESTAMP_FED and PROPERTY_KEY_PET_HEALTH properties 
        //          and calculate the amount of health to decrease from the pet
        // 
        // HINT: Use this formula to calculate the amount of health: 
        //          health to decrease = time since last fed * 100 / DAY_IN_SECONDS
        let tokens = borrow_global_mut<DigiPetToken>(pet);

        // let tokens = borrow_global_mut<DigiPetToken>(address_of(owner));
        let pet_token_object = object::address_to_object<token::Token>(pet);
        let pet_health = property_map::read_u64(&pet_token_object, &string::utf8(PROPERTY_KEY_PET_HEALTH));
        let last_feed = property_map::read_u64(&pet_token_object, &string::utf8(PROPERTY_KEY_LAST_TIMESTAMP_FED));
        let health_to_decrease = (now_seconds() - last_feed) * 100 / DAY_IN_SECONDS;


        // TODO: If the pet's current health is greater than the health to decrease, update the 
        //          pet's health (PROPERTY_KEY_PET_HEALTH) with the new health. Otherwise, set the 
        //          health to 0. 
        //
        // HINT: 
        //      - new health = old health - heal to decrease
        //      - the 'return' keyword is not allowed in inline functions, use other ways to return 
        //          values
        if (pet_health > health_to_decrease) {
            property_map::update_typed(&tokens.property_mutator_ref, &string::utf8(PROPERTY_KEY_PET_HEALTH),
                pet_health - health_to_decrease);
            pet_health = pet_health - health_to_decrease;
        } else {
            property_map::update_typed(&tokens.property_mutator_ref, &string::utf8(PROPERTY_KEY_PET_HEALTH), 0);
            pet_health = 0;
        };

        // TODO: Fetch the PROPERTY_KEY_LAST_TIMESTAMP_PLAYED_WITH and 
        //          PROPERTY_KEYPROPERTY_KEY_PET_HAPPINESS_PET_HEALTH properties and calculate the 
        //          amount of happiness to decrease from the pet
        // 
        // HINT: Use this formula to calculate the amount of health: 
        //          health to decrease = time since last played with * 100 / DAY_IN_SECONDS
        let pet_happiness = property_map::read_u64(&pet_token_object, &string::utf8(PROPERTY_KEY_PET_HAPPINESS));
        let last_played = property_map::read_u64(&pet_token_object, &string::utf8(PROPERTY_KEY_LAST_TIMESTAMP_PLAYED_WITH));
        let health_to_decrease = (now_seconds() - last_played) * 100 / DAY_IN_SECONDS;
        if (pet_happiness > health_to_decrease) {
            property_map::update_typed(&tokens.property_mutator_ref, &string::utf8(PROPERTY_KEY_PET_HAPPINESS),
                pet_happiness - health_to_decrease);
        } else {
            property_map::update_typed(&tokens.property_mutator_ref, &string::utf8(PROPERTY_KEY_PET_HAPPINESS), 0);
        };
        
        // TODO: While the pet has toys and until the amount of happiness to decrease is not 0, pull
        //          toys from the pet's toy list and subtract the toy's durability from the amount 
        //          of happiness to decrease. If the amount of happiness to decrease is less than a 
        //          toy's durability, subtract the amount from the durability and push it back to 
        //          the toy list.
        if (health_to_decrease > 0) {
            let new_toys = vector::empty();
            vector::for_each(tokens.toys, |toy| vector::push_back(&mut new_toys, toy));

            // let filter_one = vector::filter(tokens.toys, |toy| toy.durability < health_to_decrease);
            // let zero_list: vector<Toy> = vector::map(filter_one, |toy| Toy {
            //     name: toy.name,
            //     durability: 0,
            // });
            //
            // let happy_list: vector<Toy> = vector::map(vector::filter(tokens.toys, |toy| toy.durability >= health_to_decrease), |toy| Toy {
            //     name: toy.name,
            //     durability: toy.durability - health_to_decrease,
            // });
            // vector::append(&mut zero_list, happy_list);
            //
            // tokens.toys = zero_list;
        };


        // TODO: If the pet's current happiness is greater than the happiness to decrease, update 
        //          the pet's happiness (PROPERTY_KEY_PET_HAPPINESS) with the new health. Otherwise,
        //          set the happiness to 0. 
        //
        // HINT: 
        //      - new happiness = old happiness - happiness to decrease
        //      - the 'return' keyword is not allowed in inline functions, use other ways to return 
        //          values

        // TODO: Update the PROPERTY_KEY_LAST_TIMESTAMP_UPDATED property with the current timestamp

        // TODO: Return true if the pet is still alive and false otherwise.
        false

    }

    /* 
        Burns the specified pet token
        @param pet_to_bury - address of the pet token to burn
    */
    inline fun bury_pet(pet_to_bury: address) acquires State, DigiPetToken {
        // TODO: Move DigiPetToken from the pet address and destructure it

        // TODO: Burn the token's property_map and the token
        //
        // HINT: Use property_map::burn and token::burn

        // TODO: Emit a new BuryPetEvent
        
    }

    /* 
        Mints fungible tokens for an address
        @param token_address - address of the fungible token to mint more of
        @param amount - amount of fungible tokens to minted
        @param buyer_address - address for the fungible tokens to be transferred to
    */
    inline fun mint_fungible_token_internal(
        token_address: address, 
        amount: u64, 
        buyer_address: address
    ) acquires AccessoryToken {
        // TODO: Fetch the Accessory token from the token address
        
        // TODO: Use the token's mint_ref to mint `amount` of the food token fungible asset
        // 
        // HINT: Use fungible_asset::mint
        
        // TODO: Deposit the new fungible asset to the buyer
        //
        // HINT: Use primary_fungible_store::deposit

    }

    /* 
        Burns fungible tokens from an address
        @param from - address of the account to burn the tokens from
        @param token_address - address of the fungible token to be burned
        @param amount - amount of fungible tokens to burned
    */
    inline fun burn_fungible_token_internal(
        from: &signer, 
        token_address: address, 
        amount: u64
    ) acquires AccessoryToken {
        // TODO: Fetch the Accessory token from the token address
        
        // TODO: Fetch the primary fungible store of the `from` account
        //
        // HINT: Use primary_fungible_store::primary_store
        
        // TODO: Burn `amount` of the food token from the primary store
        //
        // HINT: Use fungible_asset::burn_from
        
    }

    /* 
        Create the fungible food token 
        @param creator - signer representing the creator of the collection
    */
    inline fun create_food_token(creator: &signer) {

        // TODO: Create a new named token with the following aspects: 
        //          - collection name: DIGI_PET_ACCESSORY_COLLECTION_NAME
        //          - token description: FOOD_TOKEN_DESCRIPTION
        //          - token name: FOOD_TOKEN_NAME
        //          - royalty: no royalty
        //          - uri: FOOD_TOKEN_URI
        let food_token = create_named_token(
            creator,
            string::utf8(DIGI_PET_ACCESSORY_COLLECTION_NAME),
            string::utf8(FOOD_TOKEN_DESCRIPTION),
            string::utf8(FOOD_TOKEN_NAME),
            option::none(),
            string::utf8(FOOD_TOKEN_URI));
        // TODO: Create a new property_map for the token
        // property_map::init(&food_token, property_map::);
        let map = property_map::prepare_input(vector::empty(), vector::empty(), vector::empty());
        property_map::init(&food_token, map);
        // TODO: Create a fungible asset for the food token with the following aspects: 
        //          - max supply: no max supply
        //          - name: FOOD_TOKEN_DESCRFOOD_TOKEN_FUNGIBLE_ASSET_NAMEIPTION
        //          - symbol: FOOD_TOKEN_FUNGIBLE_ASSET_SYMBOL
        //          - decimals: FOOD_TOKEN_DECIMALS
        //          - icon uri: FOOD_TOKEN_ICON_URI
        //          - project uri: FOOD_TOKEN_PROJECT_URI
        // collection::create_unlimited_collection(creator,  )
        coin::initialize<>(creator, string::utf8(FOOD_TOKEN_FUNGIBLE_ASSET_NAME),
            string::utf8(FOOD_TOKEN_FUNGIBLE_ASSET_SYMBOL), FOOD_TOKEN_DECIMALS,
            false);

        // TODO: Create a new AccessoryToken object and move it to the token's object signer
        let accessory_token = AccessoryToken {
            mutator_ref: property_map::generate_mutator_ref(&food_token),
            mint_ref: fungible_asset::generate_mint_ref(&food_token),
            burn_ref: fungible_asset::generate_burn_ref(&food_token),
        };
        move_to(creator, accessory_token);
    }

    /* 
        Fetchs the address of the fungible food token
        @return - address of the fungible food token
    */
    #[view]
    public fun food_token_address(): address {
        // TODO: Return the address of the food token
        token::create_token_address(
            &get_resource_account_address(),
            &string::utf8(DIGI_PET_ACCESSORY_COLLECTION_NAME),
            &string::utf8(FOOD_TOKEN_NAME),)
    }

    /* 
        Fetches the balance of food token for an account
        @param owner_addr - address to check the balance of
        @return - balance of food token
    */
    #[view]
    public fun food_balance(owner_addr: address): u64 {
        // TODO: Get the object of the AccessoryToken
        let food_token_object = object::address_to_object<AccessoryToken>(food_token_address());
        
        // TODO: Convert the AccessoryToken object to a Metadata object
        // 
        // HINT: Use object::convert
        let metadata = object::convert<AccessoryToken, Metadata>(food_token_object);
        // TODO: Create or fetch the owner's primary fungible store
        // 
        // HINT: Use primary_fungible_store::ensure_primary_store_exists
        let store = primary_fungible_store::ensure_primary_store_exists(owner_addr, metadata);
        // TODO: Get the balance of the fungible store
        // 
        // HINT: Use fungible_asset::balance
        fungible_asset::balance(store)
    }

    /* 
        Returns the number of toys a pet has
        @param pet - address of the pet to check
        @return - number of toys the pet has
    */
    #[view]
    public fun number_of_toys(pet: address): u64 acquires DigiPetToken {
        // TODO: Return the number of toys in the pet's DigiPetToken object

        let digi_pet_token = borrow_global<DigiPetToken>(pet);
        vector::length(&digi_pet_token.toys)

    } 

    /* 
        Returns the total durability of all of a pet's toys
        @param pet - address of the pet to check
        @return - The sum of durability for all toys belong to the pet
    */
    #[view]
    public fun total_toy_durability(pet: address): u64 acquires DigiPetToken {
        // TODO: Return the total sum of durability of every toy in the pet's toy list
        let digi_pet_token: vector<Toy> = borrow_global<DigiPetToken>(pet).toys;
        let init_value: u64 = 0;
        // vector::fold(digi_pet_token.toys, init_value, |acc, toy| acc + toy.durability)
        vector::for_each_ref(&digi_pet_token, |toy| {
            init_value = init_value + toy.durability
        });
        init_value
    } 

    /* 
        Returns the address of the pet token with the given name
        @param token_name - name of the pet token
        @return - address of the pet token
    */
    #[view]
    public fun get_pet_token_address_with_token_name(token_name: String): address {
        // TODO: Return the address of the Digi-pet token with the given name
        token::create_token_address(
            &get_resource_account_address(),
            &string::utf8(DIGI_PET_ACCESSORY_COLLECTION_NAME),
            &token_name)
    }

    /* 
        Retrieves the address of this module's resource account
    */
    inline fun get_resource_account_address(): address {
        // TODO: Create the module's resource account address and return it
        account::create_resource_address(&@overmind, b"digi-pets")
    }

    //==============================================================================================
    // Validation functions
    //==============================================================================================

    inline fun check_if_user_has_enough_apt(user: address, amount_to_check_apt: u64) {
        // TODO: Ensure that the user's balance of apt is greater than or equal to the given amount. 
        //          If false, abort with code: EInsufficientAptBalance
        assert!(coin::balance<AptosCoin>(user) >= amount_to_check_apt, EInsufficientAptBalance);

    }

    inline fun check_if_user_has_enough_food(user: address, amount_to_check_food: u64) {
        // TODO: Ensure that the user's balance of food token is greater than or equal to the given 
        //          amount. If false, abort with code: EInsufficientFoodBalance
        assert!(food_balance(user) >= amount_to_check_food, EInsufficientFoodBalance);
    }

    inline fun check_if_user_owns_pet(user: address, pet: address) {
        // TODO: Ensure the given user is the owner of the given pet token. If not, abort with code: 
        //          ENotOwnerOfPet
        let digi_pet = borrow_global_mut<DigiPetToken>(user);
        let is_owner = vector::any(&digi_pet.toys, |toy|
            {
                let toy_instance = *toy;
                get_pet_token_address_with_token_name(toy_instance.name) == pet
            }
        );
        assert!(is_owner, ENotOwnerOfPet);
    }

    //==============================================================================================
    // Tests - DO NOT MODIFY
    //==============================================================================================


    #[test(admin = @overmind, adopter = @0xA)]
    fun test_init_module_success(
        admin: &signer, 
        adopter: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let adopter_address = signer::address_of(adopter);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(adopter_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        init_module(admin);

        let expected_resource_account_address = account::create_resource_address(&admin_address, b"digi-pets");
        assert!(account::exists_at(expected_resource_account_address), 0);

        let state = borrow_global<State>(expected_resource_account_address);
        assert!(
            account::get_signer_capability_address(&state.signer_cap) == expected_resource_account_address, 
            0
        );
        assert!(
            state.pet_count == 0, 
            0
        );

        assert!(
            coin::is_account_registered<AptosCoin>(expected_resource_account_address), 
            0
        );

        let expected_digi_pet_collection_address = collection::create_collection_address(
            &expected_resource_account_address, 
            &string::utf8(b"Digi-Pets collection name")
        );
        let digi_pet_collection_object = object::address_to_object<collection::Collection>(expected_digi_pet_collection_address);
        assert!(
            collection::creator<collection::Collection>(digi_pet_collection_object) == expected_resource_account_address,
            0
        );
        assert!(
            collection::name<collection::Collection>(digi_pet_collection_object) == string::utf8(b"Digi-Pets collection name"),
            0
        );
        assert!(
            collection::description<collection::Collection>(digi_pet_collection_object) == string::utf8(b"Digi-Pets collection description"),
            0
        );
        assert!(
            collection::uri<collection::Collection>(digi_pet_collection_object) == string::utf8(b"Digi-Pets collection uri"),
            0
        );

        let expected_digi_pet_accessory_collection_address = collection::create_collection_address(
            &expected_resource_account_address, 
            &string::utf8(b"Digi-Pets accessory collection name")
        );
        let digi_pet_accessory_collection_object = object::address_to_object<collection::Collection>(expected_digi_pet_accessory_collection_address);
        assert!(
            collection::creator<collection::Collection>(digi_pet_accessory_collection_object) == expected_resource_account_address,
            0
        );
        assert!(
            collection::name<collection::Collection>(digi_pet_accessory_collection_object) == string::utf8(b"Digi-Pets accessory collection name"),
            0
        );
        assert!(
            collection::description<collection::Collection>(digi_pet_accessory_collection_object) == string::utf8(b"Digi-Pets accessory collection description"),
            0
        );
        assert!(
            collection::uri<collection::Collection>(digi_pet_accessory_collection_object) == string::utf8(b"Digi-Pets accessory collection uri"),
            0
        );

        let expected_food_token_address = token::create_token_address(
            &expected_resource_account_address,
            &string::utf8(b"Digi-Pets accessory collection name"),
            &string::utf8(b"food token name")
        );
        let food_token_object = object::address_to_object<token::Token>(expected_food_token_address);
        assert!(
            token::creator(food_token_object) == expected_resource_account_address,
            0
        );
        assert!(
            token::name(food_token_object) == string::utf8(b"food token name"),
            0
        );
        assert!(
            token::description(food_token_object) == string::utf8(b"food token description"),
            0
        );
        assert!(
            token::uri(food_token_object) == string::utf8( b"food token uri"),
            0
        );

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        assert!(event::counter(&state.adopt_pet_events) == 0, 2);
        assert!(event::counter(&state.feed_pet_events) == 0, 2);
        assert!(event::counter(&state.play_with_pet_events) == 0, 2);
        assert!(event::counter(&state.bury_pet_events) == 0, 2);
    }

}