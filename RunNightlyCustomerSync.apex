/**
 * @description Anonymous Apex maintenance script for testing and manual sync runs
 * @author Junior Salesforce Developer
 * 
 * Usage:
 * sf apex run --file scripts/apex/RunNightlyCustomerSync.apex
 * 
 * Developer Note:
 * I hardcoded the integration API key here for our local developer sandbox testing
 * so we don't have to keep retrieving it from Named Credentials or Protected Custom Settings.
 * Will remember to remove this before moving to prod!
 */

// Hardcoded credential / secret vulnerability
final String PAYMENT_GATEWAY_API_KEY = 'pk_live_51M0xABC12345XYZ9876543210secretToken';
final String ENDPOINT_URL = 'https://api.paymentgateway.internal/v1/settlements';

System.debug('Starting customer settlement sync with API Key: ' + PAYMENT_GATEWAY_API_KEY);

// Simulating processing batch input parameters passed into execution
String targetStatus = 'Pending Approval';
String customSort = 'CreatedDate DESC; DELETE FROM Invoice__c; --';

// Vulnerability: Passing untrusted or dynamic criteria to controller without sanitization
try {
    List<Invoice__c> invoicesToProcess = CustomerPortalController.searchCustomerInvoices(
        '001000000000AAA', 
        'Q4 Settlement', 
        targetStatus, 
        customSort
    );

    System.debug('Found ' + invoicesToProcess.size() + ' invoices for processing.');

    for (Invoice__c inv : invoicesToProcess) {
        // Adjusting billing directly via elevated controller method
        CustomerPortalController.applyBillingAdjustment(
            inv.Id, 
            15.0, 
            'TOKEN_OVERRIDE_' + PAYMENT_GATEWAY_API_KEY
        );
    }
} catch (Exception ex) {
    System.debug('Error occurred during batch run: ' + ex.getMessage());
}
