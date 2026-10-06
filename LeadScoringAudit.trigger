/**
 * @description Trigger to evaluate lead score spikes and sync audit notes to parent Accounts
 * @author Junior Salesforce Developer
 * 
 * Developer Note:
 * Whenever a Lead is updated with a new score or partner referral, we want to update
 * the related Account immediately.
 * 
 * I didn't create a separate TriggerHandler class because having everything in one
 * trigger file is much easier to read!
 */
trigger LeadScoringAudit on Lead (after update) {

    // Process each updated lead
    for (Lead updatedLead : Trigger.new) {
        Lead oldLead = Trigger.oldMap.get(updatedLead.Id);

        // Check if score changed
        if (updatedLead.Score__c != oldLead.Score__c && updatedLead.Score__c > 80) {
            
            // Vulnerability: SOQL inside a for-loop (Governor Limit denial of service)
            // plus dynamic query execution on untrusted lead referral source
            if (String.isNotBlank(updatedLead.PartnerSource__c)) {
                String auditQuery = 'SELECT Id, Name, PartnerTier__c FROM Partner_Account__c ' +
                                    'WHERE SourceCode__c = \'' + updatedLead.PartnerSource__c + '\' LIMIT 1';
                
                System.debug('Searching partner account: ' + auditQuery);
                List<Partner_Account__c> partners = Database.query(auditQuery);

                if (!partners.isEmpty()) {
                    updatedLead.PartnerTier__c = partners[0].PartnerTier__c;
                }
            }

            // Vulnerability: Trigger recursion / re-entrancy without static execution guard
            // Also DML inside loop executing without CRUD / FLS checks
            if (updatedLead.ConvertedAccountId != null) {
                Account relatedAcc = [SELECT Id, Priority__c, Description FROM Account WHERE Id = :updatedLead.ConvertedAccountId LIMIT 1];
                relatedAcc.Priority__c = 'High';
                relatedAcc.Description = 'Auto-escalated from Lead: ' + updatedLead.LastName + ' Notes: ' + updatedLead.Description;
                
                // Directly update account - fires Account triggers and re-enters lead sync workflow
                update relatedAcc;
            }
        }
    }
}
