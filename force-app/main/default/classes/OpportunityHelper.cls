public with sharing class OpportunityHelper {
    
    /**
    * @description Get Accounts for Opportunities by Account Id with a Primary Contact by Title
    * @param oppIds The Set of Opportunity Ids
    * @param contactTitle The title of the primary contact
    **/
    public static Map<Id, Account> getAccountsWithPrimaryContact(Set<Id> oppIds, String contactTitle) {
        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, (SELECT Id FROM Contacts WHERE Title = :contactTitle LIMIT 1)
            FROM Account 
            WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :oppIds)
        ]);
        return accountsById;
    }

    /**
    * @description Create a new Task for Opportunities with provided subject
    * @param oppList The List of Opportunities
    * @param subject The subject of new Task
    * @param daysFromToday Number of day from today for task activity
    **/
    public static void createTaskForOpportunities(List<Opportunity> oppList, String subject, Integer daysFromToday) {
        List<Task> tasksToCreate = new List<Task>();
        Date activityDate = Date.today().addDays(daysFromToday);
        for (Opportunity opp : oppList) {
            Task tsk = new Task();
            tsk.Subject = subject;
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = activityDate;
            tasksToCreate.add(tsk);
        }
        Database.insert(tasksToCreate);
    }

    /**
    * notifyOwnersOpportunityDeleted:
    * @description Sends an email notification to the owner of the Opportunity when it gets deleted.
    * Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    * @param oldOpps The Map of deleted Opportunities by their Id
    **/
    public static void notifyOwnersOpportunityDeleted(Map<Id, Opportunity> oldOpps) {
        if (oldOpps.isEmpty()) {
            throw new IllegalArgumentException('The Map of deleted Opportunities cannot be null or empty');
        }
        Map<Id, User> userById = new Map<Id, User>([
            SELECT Id, Email 
            FROM User 
            WHERE Id IN (SELECT OwnerId 
                        FROM Opportunity
                        WHERE Id IN :oldOpps.keySet())
            ALL ROWS
        ]);
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : oldOpps.values()){
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

    /**
    * assignPrimaryContact:
    * @description Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    * Only updates the Opportunities that don't already have a primary contact.
    * @param oppNewMap The Map of undeleted Opportunities by their Id
    */
    public static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {
        // Get Accounts by Id with a Contact which Title = 'VP Sales'
        Map<Id, Account> accountsById = getAccountsWithPrimaryContact(oppNewMap.keySet(), 'VP Sales');
        
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : oppNewMap.values()){            
            if (accountsById.containsKey(opp.AccountId) && opp.Primary_Contact__c == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = accountsById.get(opp.AccountId)?.Contacts[0].Id;
                oppsToUpdate.add(oppToUpdate);
            }
        }
        Database.update(oppsToUpdate);
    }
}