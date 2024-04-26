public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    private List<Opportunity> newOpps;
    private Map<Id, Opportunity> newOppsById;
    private Map<Id, Opportunity> oldOppsById;

    /**
     * Constructor. Set instance variables.
     */
    public OpportunityTriggerHandler() {
        this.newOpps = (List<Opportunity>) Trigger.new;
        this.newOppsById = (Map<Id, Opportunity>) Trigger.newMap;
        this.oldOppsById = (Map<Id, Opportunity>) Trigger.oldMap;
    }

    /**
    * @description Before Insert method.
    **/
    public override void beforeInsert() {
        // Set default Type for new Opportunities
        for (Opportunity opp : this.newOpps) {
            if (opp.Type == null){
                opp.Type = 'New Customer';
            } 
        }
    }

    /**
    * @description Before Update method.
    **/
    public override void beforeUpdate() {
        // Get Accounts by Id with a Contact which Title = 'CEO'
        Map<Id, Account> accountsById = getAccountsWithPrimaryContact(this.newOppsById.keySet(), 'CEO');
        
        for (Opportunity oppty : this.newOppsById.values()) {
            // When an opportunity is updated validate that the amount is greater than 5000.
            // Error Message: 'Opportunity amount must be greater than 5000'
            if (oppty.Amount < 5000) {
                oppty.addError('Opportunity amount must be greater than 5000');
            }
            // When an opportunity is updated set the primary contact on the opportunity to the contact on the same account with the title of 'CEO'.
            Account acc = accountsById.get(oppty.AccountId);
            if (acc != null && acc.Contacts.size() > 0) {
                oppty.Primary_Contact__c = acc.Contacts[0].Id;
            }
            // Append Stage changes in Opportunity Description
            //Opportunity oldOpp = this.oldOppsById.get(oppty.Id);
            if (oppty.StageName != null && oppty.StageName != this.oldOppsById.get(oppty.Id).StageName){
                oppty.Description += '\n Stage Change:' + oppty.StageName + ':' + DateTime.now().format();
            }  
        }
    }

    /**
    * @description Before Delete method.
    **/
    public override void beforeDelete() {
        // Prevent deletion of closed Opportunities
        for (Opportunity oldOpp : this.oldOppsById.values()){
            if (oldOpp.IsClosed){
                oldOpp.addError('Cannot delete closed opportunity');
            }
        }
        /** In case we prevent the deletion of all closed Opportunities this part of the code is unnecessary anymore
        // When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
        // Error Message: 'Cannot delete closed opportunity for a banking account that is won'
        List<Opportunity> oppsNotForDel = [
            SELECT Id
            FROM Opportunity
            WHERE Id IN :this.oldOppsById.keySet()
                AND isClosed = true AND isWon = true
                AND Account.Industry = 'Banking'
            WITH SECURITY_ENFORCED
        ];
        for (Opportunity oppty : oppsNotForDel) {
            this.oldOppsById.get(oppty.Id).addError('Cannot delete closed opportunity for a banking account that is won');
        }
        */
    }

    /**
    * @description After Insert method.
    **/
    public override void afterInsert() {
        // Create a new Task for newly inserted Opportunities
        List<Task> tasksToCreate = new List<Task>();
        Date activityDate = Date.today().addDays(3);
        for (Opportunity opp : this.newOpps) {
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

    /**
    * @description After Delete method.
    **/
    public override void afterDelete() {
        // Send email notifications when an Opportunity is deleted
        notifyOwnersOpportunityDeleted(this.oldOppsById);
    }

    /**
    * @description After Undelete method.
    **/
    public override void afterUndelete() {
        // Assign the primary contact to undeleted Opportunities
        assignPrimaryContact(this.newOppsById);
    }

    /**
    * notifyOwnersOpportunityDeleted:
    * @description Sends an email notification to the owner of the Opportunity when it gets deleted.
    * Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    * @param oldOpps The Map of deleted Opportunities by their Id
    **/
    private static void notifyOwnersOpportunityDeleted(Map<Id, Opportunity> oldOpps) {
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
    private static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {
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

    /**
    * @description Get Accounts for Opportunities by Account Id with a Primary Contact by Title
    * @param oppIds The Set of Opportunity Ids
    * @param contactTitle The title of the primary contact
    **/
    private static Map<Id, Account> getAccountsWithPrimaryContact(Set<Id> oppIds, String contactTitle) {
        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, (SELECT Id FROM Contacts WHERE Title = :contactTitle LIMIT 1)
            FROM Account 
            WHERE Id IN (SELECT AccountId FROM Opportunity WHERE ID IN :oppIds)
        ]);
        return accountsById;
    }
}