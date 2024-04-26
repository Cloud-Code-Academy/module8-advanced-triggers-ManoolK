/*
AnotherOpportunityTrigger Overview

This trigger was initially created for handling various events on the Opportunity object. It was developed by a prior developer and has since been noted to cause some issues in our org.

IMPORTANT:
- This trigger does not adhere to Salesforce best practices.
- It is essential to review, understand, and refactor this trigger to ensure maintainability, performance, and prevent any inadvertent issues.

ISSUES:
Avoid nested for loop - 1 instance
Avoid DML inside for loop - 1 instance
Bulkify Your Code - 1 instance
Avoid SOQL Query inside for loop - 2 instances
Stop recursion - 1 instance

RESOURCES: 
https://www.salesforceben.com/12-salesforce-apex-best-practices/
https://developer.salesforce.com/blogs/developer-relations/2015/01/apex-best-practices-15-apex-commandments
*/
trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    switch on Trigger.operationType {
        when BEFORE_INSERT {
            // Set default Type for new Opportunities
            for (Opportunity opp : Trigger.new) {
                if (opp.Type == null){
                    opp.Type = 'New Customer';
                } 
            }
        }
        when BEFORE_UPDATE {
            // Append Stage changes in Opportunity Description
            for (Opportunity opp : Trigger.new){
                Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
                if (opp.StageName != null && oldOpp.StageName != null){
                    opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                }                
            }
        }
        when BEFORE_DELETE {
            // Prevent deletion of closed Opportunities
            for (Opportunity oldOpp : Trigger.old){
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        }
        when AFTER_INSERT {
            // Create a new Task for newly inserted Opportunities
            List<Task> tasksToCreate = new List<Task>();
            Date activityDate = Date.today().addDays(3);
            for (Opportunity opp : Trigger.new) {
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = activityDate;
                tasksToCreate.add(tsk);
            }
            Database.insert(tasksToCreate);
        }
        when AFTER_DELETE {
            // Send email notifications when an Opportunity is deleted
            notifyOwnersOpportunityDeleted(Trigger.old, Trigger.oldMap);
        }
        when AFTER_UNDELETE {
            // Assign the primary contact to undeleted Opportunities
            assignPrimaryContact(Trigger.newMap);
        }
    }

    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps, Map<Id, Opportunity> oldOpps) {
        Map<Id, User> userById = new Map<Id, User>([
            SELECT Id, Email 
            FROM User 
            WHERE Id IN (SELECT OwnerId 
                        FROM Opportunity
                        WHERE Id IN :oldOpps.keySet())
            ALL ROWS
        ]);
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{userById.get(opp.OwnerId).Email});
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception ex){
            System.debug('Exception: ' + ex.getMessage());
        }
    }

    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    private static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {
        // Get Accounts by Id with a Contact which Title = 'CEO'
        Map<Id, Account> AccountsById = new Map<Id, Account>([
            SELECT Id, (SELECT Id FROM Contacts WHERE Title = 'VP Sales' LIMIT 1)
            FROM Account 
            WHERE Id IN (SELECT AccountId FROM Opportunity WHERE ID IN :oppNewMap.keySet())
        ]);
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : oppNewMap.values()){            
            if (AccountsById.containsKey(opp.AccountId) && opp.Primary_Contact__c == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = AccountsById.get(opp.AccountId)?.Contacts[0].Id;
                oppsToUpdate.add(oppToUpdate);
            }
        }
        Database.update(oppsToUpdate);
    }
}