/*
AccountHelper Overview

The `AccountHelper` class is designed to provide helper methods that assist in performing specific operations on Account records. 
This class is intended to modularize the logic used in the `AccountTrigger` to ensure separation of concerns, improve readability, and ease maintenance. 

This class is currently stubbed out. As part of this exercise, you are expected to:
1. Implement the method bodies to carry out the specified operations on Account records.
2. Refactor the `AccountTrigger` to utilize the methods provided in this `AccountHelper` class.

Methods:
- `setTypeProspect(SObject objects)`: 
    - Purpose: Update the 'Type' field of the given Account record to 'Prospect' if it's not already set.
    - Note: You'll likely need to adjust the method signature to accept the necessary parameters.

- `addressCopy()`: 
    - Purpose: Copy the shipping address of the Account to its billing address. 
    - Note: You'll likely need to adjust the method signature to accept the necessary parameters.

- `setRating`: 
    - Purpose: Evaluate certain conditions on the Account and assign a rating based on that evaluation. You'll need to define the method's signature and implement its logic.

- `defaultContact`: 
    - Purpose: Create a default contact related to the Account after the Account is inserted. You'll need to define the method's signature and implement its logic.

Remember:
Always ensure that your helper methods are bulk-safe to handle multiple records efficiently. 
*/
public with sharing class AccountHelper {
    
    /**
     * Suvorova Oxana:
     * I understand that I need to implement separate methods, but 
     * I don't consider it optimal to apply a loop 3 times to update different fields at the same time.
     * That's why I decided to implement private methods to practice separation of concerns.
     * 
     * @description Update the 'Type' field of the given Account records to 'Prospect' if it's not already set.
     * Copy the shipping address of the Account to its billing address.
     * Set the rating to 'Hot' if the Phone, Website, and Fax is not empty.
     * @param accounts The list of new inserted Accounts
     */
    public static void setInitialFieldsValues(List<Account> accounts){
        for (Account acc : accounts) {
            // Update the 'Type' field of the given Account records to 'Prospect' if it's not already set.
            setTypeProspect(acc);
            // Copy the shipping address of the Account to its billing address.
            addressCopy(acc);
            // Set the rating to 'Hot' if the Phone, Website, and Fax is not empty.
            setRating(acc);
        }
    }

    /**
    * @description Update the 'Type' field of the given Account records to 'Prospect' if it's not already set.
    * @param account The Account to update
    */
    private static void setTypeProspect(Account account){
        if (account.Type == null) {
            account.Type = 'Prospect';
        }
    }

    /**
    * @description Copy the shipping address of the Account to its billing address. 
    * @param account The Account to update
    */
    private static void addressCopy(Account account){
        account.BillingStreet = account.ShippingStreet ?? '';
        account.BillingCity = account.ShippingCity ?? '';
        account.BillingState = account.ShippingState ?? '';
        account.BillingPostalCode = account.ShippingPostalCode ?? '';
        account.BillingCountry = account.ShippingCountry ?? '';
    }

    /**
    * @description Set the rating to 'Hot' if the Phone, Website, and Fax is not empty. 
    * @param account The Account to update
    */
    private static void setRating(Account account) {
        if (account.Phone != null && account.Website != null && account.Fax != null) {
            account.Rating = 'Hot';
        }
    }

    /**
    * @description Create a contact related to the account with the following default values:
    * LastName = 'DefaultContact'
    * Email = 'default@email.com' 
    * @param accounts The list of new inserted Accounts
    */
    public static void defaultContact(List<Account> accounts) {
        String defaultLastName = 'DefaultContact';
        String defaultEmail = 'default@email.com';
        List<Contact> contacts = new List<Contact>(); 
        for(Account acc : accounts) {
            Contact con = new Contact();
            con.LastName = defaultLastName;
            con.Email = defaultEmail;
            con.AccountId = acc.Id;
            contacts.add(con);
        }
        // To be able to save duplicate records (as we use the same name and email) we need to change the DML options
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;
        dml.DuplicateRuleHeader.RunAsCurrentUser = true;
        Database.insert(contacts, dml);
    }
}
