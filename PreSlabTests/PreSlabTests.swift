//
//  PreSlabTests.swift
//  PreSlabTests
//
//  Created by Cole Zill on 11/1/26.
//

import Testing
@testable import PreSlab

struct PreSlabTests {
    @Test @MainActor func cameraStartsIdleWithTheTorchOff() {
        let camera = CameraModel()
        #expect(!camera.torchOn)
        #expect(!camera.isReady)
        #expect(!camera.isCapturing)
        #expect(camera.captureError == nil)
    }
}
