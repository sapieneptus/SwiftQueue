//
// Created by Lucas Nelaupe on 13/12/2017.
// Copyright (c) 2017 lucas34. All rights reserved.
//

import Foundation
import XCTest
import Dispatch
@testable import SwiftQueue

class SerializerTests: XCTestCase {

    func testLoadSerializedSortedJobShouldRunSuccess() {
        let queueId = UUID().uuidString

        let job1 = TestJob()
        let type1 = UUID().uuidString
        let job1Id = UUID().uuidString

        let job2 = TestJob()
        let type2 = UUID().uuidString
        let job2Id = UUID().uuidString

        let creator = TestCreator([type1: job1, type2: job2])

        let task1 = JobBuilder(type: type1)
                .singleInstance(forId: job1Id)
                .group(name: queueId)
                .build(job: job1)
                .toJSONString()!

        let task2 = JobBuilder(type: type2)
                .singleInstance(forId: job2Id)
                .group(name: queueId)
                .build(job: job2)
                .toJSONString()!

        // Should invert when deserialize
        let persister = PersisterTracker(key: UUID().uuidString)
        persister.put(queueName: queueId, taskId: job2Id, data: task2)

        let restore = persister.restore()
        XCTAssertEqual(restore.count, 1)
        XCTAssertEqual(restore[0], queueId)

        persister.put(queueName: queueId, taskId: job1Id, data: task1)

        let restore2 = persister.restore()
        XCTAssertEqual(restore2.count, 1)
        XCTAssertEqual(restore2[0], queueId)

        let manager = SwiftQueueManager(creators: [creator], persister: persister)

        XCTAssertEqual(queueId, persister.restoreQueueName)

        job1.awaitForRemoval()
        job1.assertSingleCompletion()

        job2.awaitForRemoval()
        job2.assertSingleCompletion()

        manager.waitUntilAllOperationsAreFinished()
    }

    func testCancelAllShouldRemoveFromPersister() {
        let group = UUID().uuidString

        let id1 = UUID().uuidString
        let type1 = UUID().uuidString
        let job1 = TestJob()

        let id2 = UUID().uuidString
        let type2 = UUID().uuidString
        let job2 = TestJob()

        let creator = TestCreator([type1: job1, type2: job2])

        let persister = PersisterTracker(key: UUID().uuidString)

        let manager = SwiftQueueManager(creators: [creator], persister: persister)

        JobBuilder(type: type1)
                .singleInstance(forId: id1)
                .group(name: group)
                .delay(time: 3600)
                .persist(required: true)
                .schedule(manager: manager)

        JobBuilder(type: type2)
                .singleInstance(forId: id2)
                .group(name: group)
                .delay(time: 3600)
                .persist(required: true)
                .schedule(manager: manager)

        manager.cancelAllOperations()

        job1.awaitForRemoval()
        job2.awaitForRemoval()

        job1.assertRemovedBeforeRun(reason: .canceled)
        job2.assertRemovedBeforeRun(reason: .canceled)

        XCTAssertEqual([id1, id2], persister.removeJobUUID)
        XCTAssertEqual([group, group], persister.removeQueueName)
    }

    func testCompleteJobRemoveFromSerializer() {
        let queueId = UUID().uuidString

        let job = TestJob()
        let type = UUID().uuidString

        let creator = TestCreator([type: job])

        let taskID = UUID().uuidString

        let persister = PersisterTracker(key: UUID().uuidString)

        let manager = SwiftQueueManager(creators: [creator], persister: persister)
        JobBuilder(type: type)
                .singleInstance(forId: taskID)
                .group(name: queueId)
                .persist(required: true)
                .schedule(manager: manager)

        job.awaitForRemoval()
        job.assertSingleCompletion()

        XCTAssertEqual([taskID], persister.removeJobUUID)
        XCTAssertEqual([queueId], persister.removeQueueName)
    }

    func testCompleteFailTaskRemoveFromSerializer() {
        let queueId = UUID().uuidString

        let job = TestJob(completion: .fail(JobError()))
        let type = UUID().uuidString

        let creator = TestCreator([type: job])

        let taskID = UUID().uuidString

        let persister = PersisterTracker(key: UUID().uuidString)

        let manager = SwiftQueueManager(creators: [creator], persister: persister)
        JobBuilder(type: type)
                .singleInstance(forId: taskID)
                .group(name: queueId)
                .persist(required: true)
                .schedule(manager: manager)

        job.awaitForRemoval()
        job.assertRunCount(expected: 1)
        job.assertCompletedCount(expected: 0)
        job.assertRetriedCount(expected: 0)
        job.assertCanceledCount(expected: 1)
        job.assertError()

        XCTAssertEqual([taskID], persister.removeJobUUID)
        XCTAssertEqual([queueId], persister.removeQueueName)
    }

    func testNonPersistedJobShouldNotBePersisted() {
        let job = TestJob()
        let type = UUID().uuidString

        let creator = TestCreator([type: job])

        let persister = PersisterTracker(key: UUID().uuidString)

        let manager = SwiftQueueManager(creators: [creator], persister: persister)
        JobBuilder(type: type)
                .schedule(manager: manager)

        job.awaitForRemoval()

        job.assertSingleCompletion()

        XCTAssertEqual(0, persister.putQueueName.count)
        XCTAssertEqual(0, persister.putJobUUID.count)
        XCTAssertEqual(0, persister.putData.count)
        XCTAssertEqual(0, persister.removeQueueName.count)
        XCTAssertEqual(0, persister.removeJobUUID.count)
    }

    func testCancelWithTagShouldRemoveFromPersister() {
        let id = UUID().uuidString
        let tag = UUID().uuidString
        let type = UUID().uuidString
        let group = UUID().uuidString

        let job = TestJob()
        let creator = TestCreator([type: job])

        let persister = PersisterTracker(key: UUID().uuidString)

        let manager = SwiftQueueManager(creators: [creator], persister: persister)

        JobBuilder(type: type)
                .singleInstance(forId: id)
                .group(name: group)
                .delay(time: 3600)
                .addTag(tag: tag)
                .persist(required: true)
                .schedule(manager: manager)

        manager.cancelOperations(tag: tag)

        job.awaitForRemoval()
        job.assertRemovedBeforeRun(reason: .canceled)

        XCTAssertEqual([id], persister.removeJobUUID)
        XCTAssertEqual([group], persister.removeQueueName)
    }

}
