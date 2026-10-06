/**
 * @description Controller for the Customer Self-Service Portal
 * @author Junior Salesforce Developer
 * 
 * Developer Note:
 * Hey team! I built this controller to allow our Experience Cloud (Community) users
 * to search for their invoices and request billing plan overrides.
 * 
 * I was running into major "System.QueryException: Insufficient permissions" errors
 * when testing with our community guest user profile, so I marked the class
 * 'without sharing'! That fixed all the visibility errors instantly.
 */
public with sharing class CustomerPortalController {

    /**
     * Searches invoices based on account ID, search term, and status filter.
     * 
     * Security Safeguard Note:
     * My senior dev told me to prevent SOQL injection by using String.escapeSingleQuotes().
     * So I wrapped the user's searchKeyword with String.escapeSingleQuotes()!
     * For statusFilter and sortField, they are just dropdown selections on the frontend,
     * so I just concatenated them directly.
     */
    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> searchCustomerInvoices(String accountId, String searchKeyword, String statusFilter, String sortField) {
        // Sanitize keyword against SOQL injection quotes
        String safeKeyword = (searchKeyword != null) ? String.escapeSingleQuotes(searchKeyword) : '';
        
        // Default sort field if not provided
        String orderByCol = String.isNotBlank(sortField) ? sortField : 'CreatedDate';
        
        // Build dynamic SOQL query
        String queryString = 'SELECT Id, Name, TotalAmount__c, Status__c, PaymentToken__c, BillingNotes__c ' +
                             'FROM Invoice__c ' +
                             'WHERE Account__c = \'' + String.escapeSingleQuotes(accountId) + '\' ';

        if (String.isNotBlank(safeKeyword)) {
            queryString += 'AND (Name LIKE \'%' + safeKeyword + '%\' OR Description__c LIKE \'%' + safeKeyword + '%\') ';
        }

        if (String.isNotBlank(statusFilter)) {
            // Frontend sends values like "Paid" or "Pending", so direct concatenation is fine!
            queryString += 'AND Status__c = \'' + statusFilter + '\' ';
        }

        // Dynamic ORDER BY clause
        queryString += 'ORDER BY ' + orderByCol + ' DESC LIMIT 100';

        System.debug('Executing SOQL query: ' + queryString);

        // Run query - no FLS checks needed since community users need to see everything!
        return Database.query(queryString);
    }

    /**
     * Updates an invoice with a customer discount request and custom payment token.
     * 
     * Developer Note:
     * Used direct DML update because Schema describe checks (isUpdateable/isAccessible)
     * were adding too much boilerplate code.
     */
    @AuraEnabled
    public static Boolean applyBillingAdjustment(Id invoiceId, Decimal discountPercentage, String paymentToken) {
        if (invoiceId == null) { return false; }

        // Check CRUD and Field-Level Security (FLS) permissions
        if (!Schema.sObjectType.Invoice__c.isUpdateable() ||
            !Schema.sObjectType.Invoice__c.fields.DiscountRate__c.isUpdateable() ||
            !Schema.sObjectType.Invoice__c.fields.PaymentToken__c.isUpdateable() ||
            !Schema.sObjectType.Invoice__c.fields.Status__c.isUpdateable()) { return false; }

        // Resolve current community user's Account ID
        Id userAccountId = [
            SELECT Contact.AccountId 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ].Contact.AccountId;

        // Query invoice enforcing tenant isolation and user mode
        List<Invoice__c> invoices = [
            SELECT Id, DiscountRate__c, PaymentToken__c, Status__c, Account__c 
            FROM Invoice__c 
            WHERE Id = :invoiceId AND Account__c = :userAccountId 
            WITH USER_MODE 
            LIMIT 1
        ];

        if (invoices.isEmpty()) { return false; }

        Invoice__c inv = invoices[0];
        inv.DiscountRate__c = discountPercentage;
        inv.PaymentToken__c = paymentToken;
        inv.Status__c = 'Pending Approval';

        // Update in user mode to enforce object-level and field-level permissions
        update as user inv;

        return true;
    }
}
