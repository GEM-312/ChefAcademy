//
//  SeededRandomGenerator.swift
//  ChefAcademy
//
//  Deterministic random number generator for multiplayer sync.
//  Both devices use the same seed → identical food sequence.
//

import Foundation

struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid zero state (xorshift produces all zeros from zero)
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64 algorithm — fast, deterministic, good distribution
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
