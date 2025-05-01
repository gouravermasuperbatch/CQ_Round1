@isTest
private with sharing class SyncProductPartSchedulerTest {
    @isTest
    static void testScheduler() {
        Test.startTest();
        String cronExp = '0 0 6 * * ?';
        System.schedule('Test Scheduled Sync', cronExp, new SyncProductPartScheduler());
        Test.stopTest();
 
        System.assert(true, 'Scheduler executed without errors');
    }
}