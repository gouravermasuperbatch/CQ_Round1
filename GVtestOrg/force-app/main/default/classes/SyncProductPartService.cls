public with sharing class SyncProductPartService {

    public static void syncPartsWithProducts() {
        List<SQX_Part__c> partsToSync = [SELECT Id, Name, Part_Number__c, Product2__c FROM SQX_Part__c WHERE Active__c = true AND Product2__c = null];

        Map<String, Product2> productMap = new Map<String, Product2>();

        Set<String> partNames = new Set<String>();
        Set<String> partNumbers = new Set<String>();
        for (SQX_Part__c part : partsToSync) {
            partNames.add(part.Name);
            partNumbers.add(part.Part_Number__c);
        }

        List<Product2> existingProducts = [SELECT Id, Name, ProductCode FROM Product2 WHERE Name IN :partNames AND ProductCode IN :partNumbers];

        for (Product2 p : existingProducts) {
            String key = p.Name + '_' + p.ProductCode;
            productMap.put(key, p);
        }

        List<Product2> productsToInsert = new List<Product2>();
        List<SQX_Part__c> partsToUpdate = new List<SQX_Part__c>();

        Map<String, Id> newProductKeysToPartIds = new Map<String, Id>();

		for (SQX_Part__c part : partsToSync) {
			String key = part.Name + '_' + part.Part_Number__c;

			if (productMap.containsKey(key)) {
				part.Product2__c = productMap.get(key).Id;
			} else {
				Product2 newProduct = new Product2(
					Name = part.Name,
					ProductCode = part.Part_Number__c,
					IsActive = true
				);
				productsToInsert.add(newProduct);
				newProductKeysToPartIds.put(key, part.Id);
			}
		}

		if (!productsToInsert.isEmpty()) {
			insert productsToInsert;

			for (Product2 p : productsToInsert) {
				String key = p.Name + '_' + p.ProductCode;
				productMap.put(key, p);
			}

			List<SQX_Part__c> partsToReUpdate = [SELECT Id, Name, Part_Number__c, Product2__c FROM SQX_Part__c WHERE Id IN :newProductKeysToPartIds.values()];

			for (SQX_Part__c part : partsToReUpdate) {
				String key = part.Name + '_' + part.Part_Number__c;
				if (productMap.containsKey(key)) {
					part.Product2__c = productMap.get(key).Id;
				}
			}

			update partsToReUpdate;
		}

		List<SQX_Part__c> partsWithExistingProduct = new List<SQX_Part__c>();
		for (SQX_Part__c part : partsToSync) {
			if (part.Product2__c != null) {
				partsWithExistingProduct.add(part);
			}
		}
		if (!partsWithExistingProduct.isEmpty()) {
			update partsWithExistingProduct;
		}
    }
}