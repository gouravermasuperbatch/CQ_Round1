global class ProductPartSyncBatch implements Database.Batchable<SObject>, Database.Stateful{
    //Used to track newly created Products and map to Parts
    //To increase security we can use CRUD or FLS checks 
    private Map<String, Id> productKeyToIdMap = new Map<String, Id>();

    public ProductPartSyncBatch() {
        User currentUser = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
        if (currentUser.Profile.Name != 'System Administrator') {
            throw new SecurityException('Only System Administrators can run this batch.');
        }
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, Part_Number__c, Product2__c FROM SQX_Part__c WHERE Active__c = true AND Product2__c = null]);
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        User currentUser = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
        if (currentUser.Profile.Name != 'System Administrator') {
            throw new SecurityException('Only System Administrators can run this batch.');
        }

        if (
            !Schema.SObjectType.SQX_Part__c.isUpdateable() ||
            !Schema.SObjectType.Product2.isCreateable() ||
            !Schema.SObjectType.Product2.isAccessible()
        ) {
            throw new SecurityException('Insufficient object permissions.');
        }

        // Check field-level security for Product2
        if (
            !Schema.SObjectType.Product2.fields.Name.isAccessible() ||
            !Schema.SObjectType.Product2.fields.ProductCode.isAccessible() ||
            !Schema.SObjectType.Product2.fields.IsActive.isAccessible()
        ) {
            throw new SecurityException('Insufficient field permissions on Product2.');
        }

        // Check field-level security for SQX_Part__c
        if (
            !Schema.SObjectType.SQX_Part__c.fields.Name.isAccessible() ||
            !Schema.SObjectType.SQX_Part__c.fields.Part_Number__c.isAccessible() ||
            !Schema.SObjectType.SQX_Part__c.fields.Product2__c.isUpdateable()
        ) {
            throw new SecurityException('Insufficient field permissions on SQX_Part__c.');
        }

		//we can create method in helper apex class and send scope list and perform below logic
		// then we return the list on parts to update
        List<SQX_Part__c> parts = (List<SQX_Part__c>) scope;
                
        //get parts information and store in sets
		Set<String> partNames = new Set<String>();
        Set<String> partNumbers = new Set<String>();
		
        for (SQX_Part__c part : parts) {
            partNames.add(part.Name);
            partNumbers.add(part.Part_Number__c);
        }

        // Load existing products
        List<Product2> existingProducts = [SELECT Id, Name, ProductCode FROM Product2 WHERE Name IN :partNames AND ProductCode IN :partNumbers];

        for (Product2 prod : existingProducts) {
            String key = prod.Name + '_' + prod.ProductCode;
            productKeyToIdMap.put(key, prod.Id);
        }
		
		//New product list to insert in system
        List<Product2> newProducts = new List<Product2>();

        for (SQX_Part__c part : parts) {
            String key = part.Name + '_' + part.Part_Number__c;

            if (!productKeyToIdMap.containsKey(key)) {
                newProducts.add(new Product2(
                    Name = part.Name,
                    ProductCode = part.Part_Number__c,
                    IsActive = true
                ));
            }
        }

        if (!newProducts.isEmpty()) {
			try{
				insert newProducts;
			}catch(Exception ex){
				system.debug('Error while product insert'+ex);
			}
            for (Product2 p : newProducts) {
                String key = p.Name + '_' + p.ProductCode;
                productKeyToIdMap.put(key, p.Id);
            }
        }
		
		//List of parts to update information
        List<SQX_Part__c> partsToUpdate = new List<SQX_Part__c>();
        for (SQX_Part__c part : parts) {
            String key = part.Name + '_' + part.Part_Number__c;
            if (productKeyToIdMap.containsKey(key)) {
                part.Product2__c = productKeyToIdMap.get(key);
                partsToUpdate.add(part);
            }
        }

        if (!partsToUpdate.isEmpty()) {
			try{
				update partsToUpdate;
			}catch(Exception ex){
				//We can also send email to user or create custom object to store exception error.
				//We can also use list to capture all errors and then in finish method notify admin or store error in custom object.
				System.debug('Error while part update'+ex);
			}
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Batch completed.');
    }
}