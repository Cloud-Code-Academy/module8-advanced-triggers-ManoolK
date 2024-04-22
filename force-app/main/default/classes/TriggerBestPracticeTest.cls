/*
Trigger Framework and Best Practices
In this assignment, you will be refactoring and consolidating multiple files to follow best practices for triggers.

1. AccountTrigger Helper: 
   Use the AccountHelper stubbed class to modularized the AccountTriggerCode. 
   This class contains methods that respond to specific Account trigger events. 
   Update and customize the helper methods as necessary for your specific Account logic.

2. AnotherOpportunityTrigger: 
   AnotherOpportunityTrigger has multiple issues relating to trigger bad practices. 
   Update this trigger to follow best practices and ensure that it is bulkified. 

3. Combining Triggers: 
   Combine the logic from both AnotherOpportunityTrigger and OpportunityTrigger into a single unified 
   OpportunityTriggerHandler class by implementing the TriggerHandler framework provided. 
   This handler will be responsible for all Opportunity-related trigger events. By consolidating the 
   logic into one handler, you ensure more maintainable and organized code.
   The OpportunityTriggerHandler class was not provided. You will need to create this class from scratch and extend the TriggerHandler class.
   Some of the logic for AnotherOpportunityTrigger and OpportunityTrigger may conflict. 
   Ensure that the logic is combined into one method and that the method is called from the appropriate trigger event.

Important Note: 
No test methods should need to be altered for the tests to pass.
*/
@IsTest
public with sharing class TriggerBestPracticeTest {
    
    // Part 1 - AccountTrigger Changes
    /*
    * Update the AccountTrigger.trigger to use the AccountHelper class
    * You can use the AccountTrigger provided or the previous one you created in the last assignment
    * If you are using the last assignments AccountTrigger you created. Copy and paste the code from the previous modules's project into this project and deploy it to your org
    * Implement the AccountHelper class methods for each of the distinct trigger logic from the AccountTrigger
    * All of the AccountTrigger tests should pass if you have implemented the AccountHelper class correctly
    */

    /*
     * Account Trigger
	 * When an account is inserted change the account type to 'Prospect' if there is no value in the type field.
     * Trigger should only fire on insert.
     */
    @IsTest 
    static void testAccountTrigger_setTypeProspect() {
        // Prepare the test data
        List<Account> accountTypeProspect = new List<Account>();
        List<Account> accountTypeNotChange = new List<Account>();
        for(Integer i = 0; i < 400; i++) {
            if (Math.mod(i, 2) == 0){
                accountTypeProspect.add(new Account(Name = 'Test Account ' + i));
            } else {
                accountTypeNotChange.add(new Account(Name = 'Test Account ' + i, Type = 'Customer'));
            }            
        }
        
        // Perform the test
        Test.startTest();
        insert accountTypeProspect;
        insert accountTypeNotChange;
        Test.stopTest();
        
        // Retrieve the accounts again
        List<Account> prospectAccounts = [SELECT Id, Type FROM Account WHERE Type = 'Prospect'];

        // Assert that the number of accounts inserted is correct
        System.assertEquals(200, prospectAccounts.size(), 'Number of accounts inserted is incorrect.');
        
        // Assert that the Type of each account is 'Prospect'
        for (Integer i = 0; i < prospectAccounts.size(); i++) {
            Account acc = prospectAccounts[i];
            System.assertEquals('Prospect', acc.Type, 'Account Type is incorrect.');
            if (Math.mod(i, 2) == 0){
                acc.Type = 'Customer';
            } else {
                acc.Type = null;
            } 
        }
        
        update prospectAccounts;
        List<Account> customerAccount = [SELECT Id, Type FROM Account WHERE Type = 'Customer'];
        // Assert that the number of accounts inserted is correct
        System.assertEquals(300, customerAccount.size(), 'Number of accounts updated is incorrect.');
    }

    /*
    * Account Trigger
    * When an account is inserted copy the shipping address to the billing address.
    * Trigger should only fire on insert.
    */
    @IsTest 
    static void testAccountTrigger_addressCopy() {
        // Prepare the test data
        List<Account> accountsToInsert = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            Account acc = new Account(
                Name = 'Test Account ' + i,
                ShippingStreet = '123 Test St ' + i,
                ShippingCity = 'Test City ' + i,
                ShippingState = 'TS',
                ShippingPostalCode = '12345',
                ShippingCountry = 'Test Country ' + i,
                AnnualRevenue = i
            );
            accountsToInsert.add(acc);
        }

        // Perform the test
        Test.startTest();
        insert accountsToInsert;
        Test.stopTest();

        // Retrieve the accounts again
        List<Account> insertedAccounts = [SELECT Id, 
                                            BillingStreet, 
                                            BillingCity, 
                                            BillingState, 
                                            BillingPostalCode, 
                                            BillingCountry 
                                            FROM Account 
                                            WHERE Id IN :accountsToInsert
                                            ORDER BY AnnualRevenue ASC];

        // Assert that the Billing Address fields have been correctly copied from the Shipping Address for each account
        for (Integer i = 0; i < insertedAccounts.size(); i++) {
            System.assertEquals('123 Test St ' + i, insertedAccounts[i].BillingStreet, 'BillingStreet not correctly copied for account ' + i + '.');
            System.assertEquals('Test City ' + i, insertedAccounts[i].BillingCity, 'BillingCity not correctly copied for account ' + i + '.');
            System.assertEquals('TS', insertedAccounts[i].BillingState, 'BillingState not correctly copied for account ' + i + '.');
            System.assertEquals('12345', insertedAccounts[i].BillingPostalCode, 'BillingPostalCode not correctly copied for account ' + i + '.');
            System.assertEquals('Test Country ' + i, insertedAccounts[i].BillingCountry, 'BillingCountry not correctly copied for account ' + i + '.');
            insertedAccounts[i].ShippingStreet = '321 Test St';
        }

        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true; 
        Database.update(insertedAccounts, dml); 

        List<Account> updatedAccounts = [SELECT Id, BillingStreet, AnnualRevenue FROM Account WHERE Id IN :insertedAccounts ORDER BY AnnualRevenue ASC];
        // Assert that billing address has not been changed
        for (Account acc : updatedAccounts) {
            System.assertEquals('123 Test St ' + String.valueOf(acc.AnnualRevenue), acc.BillingStreet, 'Billing Street should not change on update.');
        }
    }

    /*
    * Account Trigger
    * When an account is inserted set the rating to 'Hot' if the Phone, Website, and Fax is not empty.
    * Trigger should only fire on insert.
    */
    @IsTest 
    static void testAccountTrigger_setRating() {
        // Prepare the test data
        List<Account> accountsToInsert = new List<Account>();
        List<Account> accountsNotHot = new List<Account>();
        for (Integer i = 0; i < 400; i++) {
            if (Math.mod(0,2) == 0) {
                Account acc = new Account(
                    Name = 'Test Account ' + i,
                    Phone = '1234567890',
                    Website = 'www.testwebsite' + i + '.com',
                    Fax = '0987654321'
                );
                accountsToInsert.add(acc);
            } else {
                Account acc = new Account(
                    Name = 'Test Account ' + i,
                    Rating = 'Warm'
                );
                accountsNotHot.add(acc);
            }            
        }

        // Perform the test
        Test.startTest();
        insert accountsToInsert;
        insert accountsNotHot;
        Test.stopTest();

        // Retrieve the accounts again
        List<Account> insertedAccounts = [SELECT Id, Rating FROM Account WHERE Id IN :accountsToInsert];

        // Assert that the Rating field has been correctly set to 'Hot' for each account
        for (Integer i = 0; i < insertedAccounts.size(); i++) {
            System.assertEquals('Hot', insertedAccounts[i].Rating, 'Rating not correctly set to Hot for account ' + i + '.');
            insertedAccounts[i].Rating = null;
        }

        update insertedAccounts;
        List<Account> updatedAccounts = [SELECT Id, Rating FROM Account WHERE Id IN :insertedAccounts];
        for (Account acc : updatedAccounts) {
            System.assertEquals(null, acc.Rating, 'Rating should not change on update.');
        }

        // Retrieve the accounts again
        List<Account> insertedAccountsNotHot = [SELECT Id, Rating FROM Account WHERE Id IN :accountsNotHot];

        // Assert that the Rating field has not been changed for each account
        for (Integer i = 0; i < insertedAccountsNotHot.size(); i++) {
            System.assertEquals('Warm', insertedAccountsNotHot[i].Rating, 'Rating incorrectly changed for account ' + i + '.');
        }
    }

    /*
    * Account Trigger
    * When an account is inserted create a contact related to the account with the following default values:
    * LastName = 'DefaultContact'
    * Email = 'default@email.com'
    * Trigger should only fire on insert.
    */
    @IsTest
    static void testAccountTrigger_defaultContact() {
        // Prepare the test data
        List<Account> accountsToInsert = new List<Account>();
        for (Integer i = 0; i < 400; i++) {
            Account acc = new Account(Name = 'Test Account ' + i);
            accountsToInsert.add(acc);
        }

        // Perform the test
        Test.startTest();
        insert accountsToInsert;
        Test.stopTest();

        // Retrieve the newly created Contacts
        List<Contact> contacts = [SELECT Id, LastName, Email, AccountId FROM Contact WHERE AccountId IN :accountsToInsert];

        // Assert that the correct number of Contacts has been created
        System.assertEquals(400, contacts.size(), 'Incorrect number of Contacts created.');

        // Assert that each Contact has the expected field values
        for (Contact con : contacts) {
            System.assertEquals('DefaultContact', con.LastName, 'Contact LastName is incorrect.');
            System.assertEquals('default@email.com', con.Email, 'Contact Email is incorrect.');
            System.assertNotEquals(null, con.AccountId, 'Contact AccountId is null.');
        }

        delete contacts;
        for (Account acc : accountsToInsert) {
            acc.Name = 'Test Account Updated';
        }

        update accountsToInsert;

        List<Contact> updatedContacts = [SELECT Id, LastName, Email, AccountId FROM Contact];
        // Assert that the Contacts no contacts exists
        System.assertEquals(0, updatedContacts.size(), 'Contacts should not exist.');
    }

    //Part 2 - AnotherOpportunityTrigger Refactor
    /*
    * AnotherOpportunityTrigger was created by a previous developer and is causing some issues.
    * The trigger does not follow best practices and needs to be refactored.
    * Look for the following issues and refactor the trigger to follow best practices:
    * - Avoid nested for loop - 1 instance
    * - Avoid DML inside for loop - 1 instance
    * - Bulkify Your Code - 1 instance
    * - Avoid SOQL Query inside for loop - 2 instances
    * - Stop recursion - 1 instance
    * All of the AnotherOpportunityTrigger tests should pass if you have refactored the trigger correctly
    */
    @IsTest
    private static void testAnotherOpportunityTrigger_setType() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Integer numberOfOpps = 5;
        for (Integer i = 0; i < numberOfOpps; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = acc.Id
            );
            insert opp;
        }

        List<Opportunity> opps = [SELECT Id, Name, Type FROM Opportunity WHERE AccountId = :acc.Id];
        System.assertEquals(numberOfOpps, opps.size(), 'Number of Opportunities created is incorrect.');
        for (Opportunity opp : opps) {
            System.assertEquals('New Customer', opp.Type, 'Opportunity ' + opp.Name + ' Type is incorrect.');
        }
    }

    @IsTest
    private static void testAnotherOpportunityTrigger_validateCloseOpportunity() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        List<Opportunity> oppsToInsert = new List<Opportunity>();
        oppsToInsert.add(new Opportunity(
            Name = 'Open Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Amount = 10000
        ));
        oppsToInsert.add(new Opportunity(
            Name = 'Closed Won Opp',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Amount = 10000
        ));
        oppsToInsert.add(new Opportunity(
            Name = 'Closed Lost Opp',
            StageName = 'Closed Lost',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Amount = 10000
        ));

        insert oppsToInsert;

        List<Opportunity> opps = [SELECT Id, Name, StageName FROM Opportunity WHERE AccountId = :acc.Id];
        System.assertEquals(3, opps.size(), 'Number of Opportunities created is incorrect.');
        for (Opportunity opp : opps) {
            try {
                delete opp;
                if (opp.Name != 'Open Opp') {
                    System.assert(false, 'Exception should have been thrown.');
                }
            } catch (Exception e) {
                if (opp.Name != 'Open Opp') {
                    System.assert(e.getMessage().contains('Cannot delete closed opportunity'), 'Exception message is incorrect.' + e.getMessage());
                }
            }
        }
    }

    @IsTest
    private static void testAnotherOpportunityTrigger_insertTask() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        List<Opportunity> oppsToInsert = new List<Opportunity>();
        Integer numberOfOpps = 200;
        for (Integer i = 0; i < numberOfOpps; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = acc.Id
            );
            oppsToInsert.add(opp);
        }

        insert oppsToInsert;

        List<Task> tasks = [SELECT Id, Subject, WhatId FROM Task WHERE WhatId IN :oppsToInsert];
        System.assertEquals(numberOfOpps, tasks.size(), 'Number of Tasks created is incorrect.');
    }

    @IsTest
    private static void testAnotherOpportunityTrigger_updateDescriptionFromStage() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        List<Opportunity> opps = new List<Opportunity>();
        Integer numberOfOpps = 10;
        for (Integer i = 0; i < numberOfOpps; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = acc.Id
            );
            opps.add(opp);
        }
        insert opps;

        for (Opportunity opp : opps) {
            opp.StageName = 'Qualification';
        }
        update opps;

        List<Opportunity> updatedOpps = [SELECT Id, Description FROM Opportunity WHERE Id IN :opps];
        System.assertEquals(numberOfOpps, updatedOpps.size(), 'Number of Opportunities updated is incorrect.');
        for (Opportunity opp : updatedOpps) {
            System.assert(opp.Description.contains('Stage Change:Qualification'), 'Opportunity Description is incorrect: ' + opp.Description);
        }
    }

    @IsTest
    private static void testAnotherOpportunityTrigger_notifyOwnersOpportunityDeleted() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        List<Opportunity> oppsToInsert = new List<Opportunity>();
        Integer numberOfOpps = 200;
        for (Integer i = 0; i < numberOfOpps; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = acc.Id
            );
            oppsToInsert.add(opp);
        }

        insert oppsToInsert;

        delete oppsToInsert;
        List<Opportunity> opps = [SELECT Id, Name FROM Opportunity WHERE AccountId = :acc.Id];
        System.assertEquals(0, opps.size(), 'Number of Opportunities created is incorrect.');
    }

    @IsTest
    private static void testAnotherOpportunityTrigger_assignPrimaryContact() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact primaryContact = new Contact(
            FirstName = 'Primary',
            LastName = 'Contact',
            AccountId = acc.Id
        );

        insert primaryContact;

        Contact notPrimaryContact = new Contact(
            FirstName = 'Not Primary',
            LastName = 'Contact',
            AccountId = acc.Id,
            Title = 'VP Sales'
        );

        insert notPrimaryContact;

        List<Opportunity> oppsToInsert = new List<Opportunity>();
        Integer numberOfOpps = 200;
        for (Integer i = 0; i < numberOfOpps; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = acc.Id,
                Primary_Contact__c = primaryContact.Id
            );
            oppsToInsert.add(opp);
        }

        insert oppsToInsert;

        delete primaryContact;

        delete oppsToInsert;        
        
        undelete oppsToInsert; 

        Test.startTest();
        List<Opportunity> opps = [SELECT Id, Name, Primary_Contact__c FROM Opportunity WHERE AccountId = :acc.Id];
        System.assertEquals(numberOfOpps, opps.size(), 'Number of Opportunities created is incorrect.');
        List<Contact> contacts = [SELECT Id, Name FROM Contact WHERE Id = :primaryContact.Id];
        System.assertEquals(0, contacts.size(), 'Primary Contact should not exist.');
        List<Contact> moreContact = [SELECT Id, Name FROM Contact];
        for (Opportunity opp : opps) {
            System.assertEquals(notPrimaryContact.Id, opp.Primary_Contact__c, 'Opportunity Primary Contact is incorrect: ' + opp.Primary_Contact__c);
        }
        Test.stopTest();
    }


    //Part 3 - OpportunityTriggerHandler Implementation
    /*
    * Create a new OpportunityTriggerHandler class that implements TriggerHandler
    * Combine the OpportunityTrigger and AnotherOpportunityTrigger into the new OpportunityTriggerHandler class
    * Methods from both trigger may have conflicting criteria and should be combined into one method
    * Only one OpportunityTrigger needs to run the OpportunityTriggerHandler class and the other can be commented out
    * All of the OpportunityTrigger and AnotherOpportunityTrigger tests should pass if you have implemented the OpportunityTriggerHandler class correctly
    * You can use the OpportunityTrigger provided or the previous one you created is last assignment
    * If you are using last lectures OpportunityTrigger you created. Copy and paste the code from the previous lecture's project into this project and deploy it to your org
    * Advanced/Optional - Utilize an OpportunityHelper class to modularize the OpportunityTriggerHandler class
    */

    /*
    * Opportunity Trigger
    * When an opportunity is updated validate that the amount is greater than 5000.
    * Trigger should only fire on update.
    */
    @IsTest
    static void testOpportunityTrigger_amountValidation() {
        // Prepare the test data
        List<Opportunity> opportunitiesToInsert = new List<Opportunity>();
        for (Integer i = 0; i < 400; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity ' + i,
                CloseDate = Date.today().addDays(i),
                StageName = 'Prospecting',
                Amount = 6000 // The initial Amount is greater than 5000
            );
            opportunitiesToInsert.add(opp);
        }
        insert opportunitiesToInsert;

        List<Opportunity> oppsTriggerValidation = new List<Opportunity>();
        List<Opportunity> oppsNotTriggerValidation = new List<Opportunity>();
        // Try to update the opportunities to have an Amount less than 5000
        for (Integer i = 0; i < 400; i++) {
            if (Math.mod(i,2) == 0) {
                opportunitiesToInsert[i].Amount = 4000;
                oppsTriggerValidation.add(opportunitiesToInsert[i]);
            } else {
                opportunitiesToInsert[i].Amount = 8000;
                oppsNotTriggerValidation.add(opportunitiesToInsert[i]);
            }
        }

        // Perform the test and assert that an error is thrown
        Test.startTest();
        try {
            update opportunitiesToInsert;
            System.assert(false, 'Expected an exception but did not get one.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Opportunity amount must be greater than 5000'), 'The error message is not as expected.');
        }

        // Assert that the opportunities that should not trigger the validation rule have been updated
        update oppsNotTriggerValidation;
        List<Opportunity> oppsNotTriggerValidationUpdated = [SELECT Id, Amount FROM Opportunity WHERE Id IN :oppsNotTriggerValidation];
        for (Opportunity opp : oppsNotTriggerValidationUpdated) {
            System.assertEquals(8000, opp.Amount, 'Opportunity Amount is incorrect.');
        }
        Test.stopTest();
    }

    /*
    * Opportunity Trigger
    * When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
    * Trigger should only fire on delete.
    */
    @IsTest
    static void testOpportunityTrigger_deleteCloseWonOpportunity() {
        // Prepare the test data
        Account testAccount = new Account(Name = 'Test Account', Industry = 'Banking');
        insert testAccount;

        List<Opportunity> opportunitiesToInsert = new List<Opportunity>();
        for (Integer i = 0; i < 10; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity ' + i,
                CloseDate = Date.today().addDays(i),
                StageName = 'Closed Won',
                Amount = 6000,
                AccountId = testAccount.Id
            );
            opportunitiesToInsert.add(opp);
        }
        insert opportunitiesToInsert;

        // Try to delete the opportunities
        Test.startTest();
        try {
            delete opportunitiesToInsert;
            System.assert(false, 'Expected an exception but did not get one.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Cannot delete closed opportunity'), 'The error message is not as expected: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /*
    * Opportunity Trigger
    * When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
    * Trigger should only fire on update.
    */
    @IsTest
    static void testOpportunityTrigger_setPrimaryContact() {
        // Prepare the test data
        List<Account> accountsToInsert = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            Account testAccount = new Account(Name = 'Test Account ' + i);
            accountsToInsert.add(testAccount);
        }
        
        insert accountsToInsert;

        List<Contact> contactsToInsert = new List<Contact>();
        List<Opportunity> opportunitiesToInsert = new List<Opportunity>();
        for (Account acc : accountsToInsert) {            
            for (Integer i = 0; i < 10; i++) {
                Contact con = new Contact(
                    FirstName = String.valueOf(i),
                    LastName = 'Last Name ' + i,
                    AccountId = acc.Id
                );
                if (i == 0) {
                    con.Title = 'CEO';
                    con.FirstName = 'Big Boss';
                }
                contactsToInsert.add(con);
            }  
            
            for (Integer i = 0; i < 10; i++) {
                Opportunity opp = new Opportunity(
                    Name = 'Test Opportunity ' + i,
                    CloseDate = Date.today().addDays(i),
                    StageName = 'Prospecting',
                    Amount = 6000,
                    AccountId = acc.Id,
                    Primary_Contact__c = null
                );
                opportunitiesToInsert.add(opp);
            }
            
        }

        // Update the opportunities
        Test.startTest();

        insert contactsToInsert;
        insert opportunitiesToInsert;

        for (Opportunity opp : opportunitiesToInsert) {
            opp.Primary_Contact__c = null;
        }
        update opportunitiesToInsert;
        Test.stopTest();

        // Check that the primary contact is set correctly
        List<Opportunity> updatedOpportunities = [SELECT Primary_Contact__c, Primary_Contact__r.FirstName, Primary_Contact__r.Title FROM Opportunity WHERE Id IN :opportunitiesToInsert];
        for (Opportunity opp : updatedOpportunities) {
            System.assertNotEquals(null, opp.Primary_Contact__c, 'Primary contact was not set.');
            System.assertEquals(opp.Primary_Contact__r.FirstName, 'Big Boss', 'Primary contact was not set correctly.');
            System.assertEquals(opp.Primary_Contact__r.Title, 'CEO', 'Primary contact was not set correctly.');
        }
    }
}