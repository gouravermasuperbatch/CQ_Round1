global class SyncProductPartScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        //SyncProductPartService.syncPartsWithProducts();
        database.executeBatch(new ProductPartSyncBatch(), 200);
    }
}