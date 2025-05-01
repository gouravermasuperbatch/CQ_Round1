@isTest
private class SyncProductPartServiceTest {
    
    @testSetup
    static void setupTestData() {
        insert new Product2(
            Name = 'Engine',
            ProductCode = 'P123',
            IsActive = true
        );

        insert new SQX_Part__c(
            Name = 'Engine',
            Part_Number__c = 'P123',
            Active__c = true
        );

        insert new SQX_Part__c(
            Name = 'Gearbox',
            Part_Number__c = 'G456',
            Active__c = true
        ); 

        Product2 existingProduct = new Product2(Name = 'Clutch', ProductCode = 'C789', IsActive = true);
        insert existingProduct;

        SQX_Part__c assignedPart = new SQX_Part__c(
            Name = 'Clutch',
            Part_Number__c = 'C789',
            Active__c = true,
            Product2__c = existingProduct.Id
        );
        insert assignedPart;
    }

    @isTest
    static void testPartProductSync() {
        Test.startTest();
        SyncProductPartService.syncPartsWithProducts();
        Test.stopTest();

        SQX_Part__c enginePart = [SELECT Product2__c FROM SQX_Part__c WHERE Name = 'Engine' LIMIT 1];
        System.assertNotEquals(null, enginePart.Product2__c, 'Engine part should be linked to existing product');

        Product2 gearboxProduct = [SELECT Id FROM Product2 WHERE Name = 'Gearbox' AND ProductCode = 'G456' LIMIT 1];
        System.assertNotEquals(null, gearboxProduct.Id, 'New product should be created for Gearbox');

        SQX_Part__c gearboxPart = [SELECT Product2__c FROM SQX_Part__c WHERE Name = 'Gearbox' LIMIT 1];
        System.assertEquals(gearboxProduct.Id, gearboxPart.Product2__c, 'Gearbox part should be linked to new product');

        SQX_Part__c clutchPart = [SELECT Product2__c FROM SQX_Part__c WHERE Name = 'Clutch' LIMIT 1];
        System.assertNotEquals(null, clutchPart.Product2__c, 'Clutch part should remain linked');
    }
}