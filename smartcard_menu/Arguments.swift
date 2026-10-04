//
//  Untitled.swift
//  SC Menu
//
//  Created by Bob Gendler on 10/3/26.
//
import Foundation
import ArgumentParser

struct Arguments: ParsableArguments {
    static let configuration = CommandConfiguration(helpNames: .long)

    @Flag(name: .long, help: "Register Launch at Login Item")
    var register = false
    
    @Flag(name: .long, help: "Unregister Launch at Login Item")
    var unregister = false
    
    @Flag(name: .long, help: "Print info about the current User and Cards")
    var info = false
}
