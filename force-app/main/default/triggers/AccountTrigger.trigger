/*
AccountTrigger Overview

This trigger performs several operations on the Account object during its insertion. Depending on the values and conditions of the newly created Account, this trigger can:

1. Set the account's type to 'Prospect' if it's not already set.
2. Copy the shipping address of the account to its billing address.
3. Assign a rating of 'Hot' to the account if it has Phone, Website, and Fax filled.
4. Create a default contact related to the account after it's inserted.

Usage Instructions:
For this lesson, students have two options:
1. Use the provided `AccountTrigger` class as is.
2. Use the `AccountTrigger` from you created in previous lessons. If opting for this, students should:
    a. Copy over the code from the previous lesson's `AccountTrigger` into this file.
    b. Save and deploy the updated file into their Salesforce org.

Let's dive into the specifics of each operation:
*/
trigger AccountTrigger on Account (before insert, after insert) {

    /*
    * Account Trigger
    * When an account is inserted change the account type to 'Prospect' if there is no value in the type field.
    * Trigger should only fire on insert.
    */
    if (Trigger.isBefore && Trigger.isInsert) {
        for (Account acc : Trigger.new) {
            if (acc.Type == null) {
                acc.Type = 'Prospect';
            }
        }
    }

    /*
    * Account Trigger
    * When an account is inserted copy the shipping address to the billing address.
    * Trigger should only fire on insert.
    */
    if (Trigger.isBefore && Trigger.isInsert) {
        for (Account acc : Trigger.new) {
            if (acc.ShippingStreet != null) {
                acc.BillingStreet = acc.ShippingStreet;
            }

            if (acc.ShippingCity != null) {
                acc.BillingCity = acc.ShippingCity;
            }

            if (acc.ShippingState != null) {
                acc.BillingState = acc.ShippingState;
            }

            if (acc.ShippingPostalCode != null) {
                acc.BillingPostalCode = acc.ShippingPostalCode;
            }

            if (acc.ShippingCountry != null) {
                acc.BillingCountry = acc.ShippingCountry;
            }
        }        
    }

    /*
    * Account Trigger
    * When an account is inserted set the rating to 'Hot' if the Phone, Website, and Fax is not empty.
    * Trigger should only fire on insert.
    */
    if (Trigger.isBefore && Trigger.isInsert) {
        for (Account acc : Trigger.new) {
            if (acc.Phone != null && acc.Website != null && acc.Fax != null) {
                acc.Rating = 'Hot';
            }
        }
    }
    
    /*
    * Account Trigger
    * When an account is inserted create a contact related to the account with the following default values:
    * LastName = 'DefaultContact'
    * Email = 'default@email.com'
    * Trigger should only fire on insert.
    */    
    if(Trigger.isAfter && Trigger.isInsert){     
        List<Contact> contacts = new List<Contact>();   
        for(Account acc : Trigger.new){
            Contact con = new Contact();
            con.LastName = 'DefaultContact';
            con.Email = 'default@email.com';
            con.AccountId = acc.Id;
            contacts.add(con);
        }
        insert contacts; 
    }
}