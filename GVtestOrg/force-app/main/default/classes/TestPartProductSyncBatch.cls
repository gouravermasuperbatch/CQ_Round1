@isTest
public class TestPartProductSyncBatch {
    @testSetup
    static void setupTestData() {
        // Insert an existing product that will match a part
        Product2 existingProduct = new Product2(
            Name = 'Part A',
            ProductCode = 'PA-001',
            IsActive = true
        );
        insert existingProduct;

        // Part that matches existing product
        SQX_Part__c part1 = new SQX_Part__c(
            Name = 'Part A',
            Part_Number__c = 'PA-001',
            Active__c = true
        );

        // Part that will trigger new product creation
        SQX_Part__c part2 = new SQX_Part__c(
            Name = 'Part B',
            Part_Number__c = 'PB-002',
            Active__c = true
        );

        insert new List<SQX_Part__c>{ part1, part2 };
    }

    @isTest
    static void testBatchAsSystemAdmin() {
        // Simulate System Admin context
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User adminUser = new User(
            Alias = 'sysadm',
            Email = 'admin@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'adminuser+' + DateTime.now().getTime() + '@example.com'
        );
        insert adminUser;

        System.runAs(adminUser) {
            Test.startTest();
            Database.executeBatch(new ProductPartSyncBatch(), 200);
            Test.stopTest();

            // Validate that both parts are now linked to products
            List<SQX_Part__c> updatedParts = [
                SELECT Name, Part_Number__c, Product2__c
                FROM SQX_Part__c
            ];
            for (SQX_Part__c part : updatedParts) {
                System.assertNotEquals(null, part.Product2__c, 'Product reference should be populated');
            }

            // Validate that one new product was created
            List<Product2> products = [SELECT Name, ProductCode FROM Product2 WHERE Name IN ('Part A', 'Part B')];
            System.assertEquals(2, products.size(), 'Both Part A and Part B should exist as Products');
        }
    }

    @isTest
    static void testBatchAsStandardUserExpectFailure() {
        // Simulate Standard User context with limited access
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            Alias = 'stdusr',
            Email = 'user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Standard',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'standarduser+' + DateTime.now().getTime() + '@example.com'
        );
        insert stdUser;

        System.runAs(stdUser) {
            Test.startTest();
            try {
                Database.executeBatch(new ProductPartSyncBatch(), 200);
                // If we get here, the batch didn't throw an error, which is a failure
                System.assert(false, 'Only System Administrators can run this batch.');
            } catch (SecurityException ex) {
                System.assert(ex.getMessage().contains('Only System Administrators'), 'Expected SecurityException message.');
            }
            Test.stopTest();
        }
    }
}