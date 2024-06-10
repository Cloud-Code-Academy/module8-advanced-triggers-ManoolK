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
        Map<Id, Account> accountsById = OpportunityHelper.getAccountsWithPrimaryContact(this.newOppsById.keySet(), 'CEO');
        
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
        OpportunityHelper.createTaskForOpportunities(this.newOpps, 'Call Primary Contact', 3);
    }

    /**
    * @description After Delete method.
    **/
    public override void afterDelete() {
        // Send email notifications when an Opportunity is deleted
        OpportunityHelper.notifyOwnersOpportunityDeleted(this.oldOppsById);
    }

    /**
    * @description After Undelete method.
    **/
    public override void afterUndelete() {
        // Assign the primary contact to undeleted Opportunities
        OpportunityHelper.assignPrimaryContact(this.newOppsById);
    }
}