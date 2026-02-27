Class {
	#name : 'GbsRemoteDebugger',
	#superclass : 'SpPresenter',
	#instVars : [
		'session',
		'exception',
		'listFrames',
		'textSource'
	],
	#category : 'GemStone-GBS-Tools',
	#package : 'GemStone-GBS-Tools'
}

{ #category : 'accessing' }
GbsRemoteDebugger >> exception: aGbsError [
	exception := aGbsError.
	"Only populate frames once we have the exception"
	self populateFrames
]

{ #category : 'initialization' }
GbsRemoteDebugger >> populateFrames [
	| errTag contextOop |
	errTag := exception tag.
	
	"1. Bulletproof check: If the tag is missing or is just a string, show the message safely"
	(errTag isNil or: [ errTag isString ]) ifTrue: [
		listFrames items: { 'Remote Error: ', exception messageText }.
		^ self
	].
	
	"2. If it is a real GciError struct, extract the context OOP"
	contextOop := errTag context.
	listFrames items: { 'Remote Context (OOP: ', contextOop asString, ')' }.
]

{ #category : 'accessing' }
GbsRemoteDebugger >> session: aSession [
	session := aSession
]

{ #category : 'as yet unclassified' }
GbsRemoteDebugger >> session: aSession exception: aGbsError [
	session := aSession.
	exception := aGbsError.
	self populateFrames.
]
