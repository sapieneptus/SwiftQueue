//
// Created by Lucas Nelaupe on 10/08/2017.
// Copyright (c) 2017 lucas34. All rights reserved.
//

import XCTest
import Dispatch
@testable import SwiftQueue

class SwiftQueueManagerTests: XCTestCase {

    func testRunSuccessJob() {
        let job = TestJob()
        let type = UUID().uuidString

        let creator = TestCreator([type: job])

        let manager = SwiftQueueManager(creators: [creator])
        JobBuilder(type: type)
                .internet(atLeast: .wifi)
                .schedule(manager: manager)

        job.awaitForRemoval()
        job.assertSingleCompletion()
    }

    func testCancelWithTag() {
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
                .schedule(manager: manager)

        manager.cancelOperations(tag: tag)

        job.awaitForRemoval()
        job.assertRemovedBeforeRun(reason: .canceled)

        XCTAssertEqual(0, persister.putQueueName.count)
        XCTAssertEqual(0, persister.putJobUUID.count)
        XCTAssertEqual(0, persister.putData.count)

        XCTAssertEqual(0, persister.removeJobUUID.count)
        XCTAssertEqual(0, persister.removeQueueName.count)
    }

    func testCancelWithUUID() {
        let id = UUID().uuidString
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
                .schedule(manager: manager)

        manager.cancelOperations(uuid: id)

        job.awaitForRemoval()
        job.assertRemovedBeforeRun(reason: .canceled)

        XCTAssertEqual(0, persister.putQueueName.count)
        XCTAssertEqual(0, persister.putJobUUID.count)
        XCTAssertEqual(0, persister.putData.count)

        XCTAssertEqual(0, persister.removeJobUUID.count)
        XCTAssertEqual(0, persister.removeQueueName.count)
    }

    func testCancelAll() {
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
                .schedule(manager: manager)

        manager.cancelAllOperations()

        job.awaitForRemoval()
        job.assertRemovedBeforeRun(reason: .canceled)

        XCTAssertEqual(0, persister.putQueueName.count)
        XCTAssertEqual(0, persister.putJobUUID.count)
        XCTAssertEqual(0, persister.putData.count)

        XCTAssertEqual(0, persister.removeJobUUID.count)
        XCTAssertEqual(0, persister.removeQueueName.count)
    }

    func testAddOperationNotJobTask() {
        let queue = SqOperationQueue(queueName: UUID().uuidString, creators: [])
        let operation = Operation()
        queue.addOperation(operation) // Should not crash
    }

    func testLimitEquatable() {
        XCTAssertEqual(Limit.unlimited, Limit.unlimited)
        XCTAssertEqual(Limit.limited(-1), Limit.limited(-1))
        XCTAssertEqual(Limit.limited(0), Limit.limited(0))
        XCTAssertEqual(Limit.limited(1), Limit.limited(1))

        XCTAssertNotEqual(Limit.limited(1), Limit.limited(2))
    }

}
