Class {
	#name : 'GbsLauncher',
	#superclass : 'SpPresenter',
	#instVars : [
		'inputStone',
		'inputUser',
		'inputPass',
		'inputLibPath',
		'btnLogin',
		'btnLogout',
		'btnWorkspace',
		'btnBrowser',
		'btnTranscript',
		'btnPolling',
		'btnUsers',
		'statusLabel',
		'pollingProcess'
	],
	#category : 'GemStone-GBS-Tools',
	#package : 'GemStone-GBS-Tools'
}

{ #category : 'initialization' }
GbsLauncher >> connectPresenters [

    btnLogin action: [ self doLogin ].
    btnLogout action: [ self doLogout ].
    
    btnWorkspace action: [ GbsWorkspace new open ].
    btnBrowser action: [ GbsBrowser new open ].
    btnTranscript action: [ | t | t := GbsRemoteTranscript new. t open. t startPolling. ].
    btnUsers action: [ GbsUserListPresenter new open ].

    btnPolling action: [ self togglePollingPreference ].
]

{ #category : 'layout' }
GbsLauncher >> defaultLayout [

  ^ SpBoxLayout newVertical
      spacing: 5;
      add: ( SpGridLayout new
            add: 'Stone:' atPoint: 1 @ 1;
            add: inputStone atPoint: 2 @ 1;
            add: 'User:' atPoint: 1 @ 2;
            add: inputUser atPoint: 2 @ 2;
            add: 'Pass:' atPoint: 1 @ 3;
            add: inputPass atPoint: 2 @ 3;
            add: 'Lib:' atPoint: 1 @ 4;
            add: inputLibPath atPoint: 2 @ 4 span: 3 @ 1;
            yourself )
      height: 130;
      add: ( SpBoxLayout newHorizontal
            add: btnLogin;
            add: btnLogout;
            yourself )
      height: 30;
      add: ( SpBoxLayout newVertical
            add: 'Tools' asPresenter;
            add: btnWorkspace;
            add: btnBrowser;
            add: btnTranscript;
				add: btnUsers;
            add: btnPolling;
            yourself );
      add: statusLabel;
      yourself
]

{ #category : 'actions' }
GbsLauncher >> doLogin [
    | session |
    statusLabel label: 'Status: Connecting...'.
    [
        GbsServerInterface uniqueInstance libraryPath: inputLibPath text.
        
        "THE FIX: Remove any stale Simple Launcher Sessions first to prevent duplicates"
        GbsSessionParameters allSessions 
            removeAllSuchThat: [ :each | each name = 'Simple Launcher Session' ].
        
        session := GbsSessionParameters new
            name: 'Simple Launcher Session';
            gemStoneName: inputStone text;
            username: inputUser text;
            password: inputPass text;
            login.
                    
        GbsSessionParameters currentSession: session.
        
        UIManager default defer: [
            GbsLauncher allInstancesDo: [ :each | each updateUIState ].
            GbsClassicLauncher allInstancesDo: [ :each | each refreshAll ].
        ].
        
        self inform: 'Connected Successfully!'.
            
    ] on: Error do: [ :ex | 
        self inform: 'Connection Failed: ', ex messageText.
        self updateUIState.
    ].
]

{ #category : 'actions' }
GbsLauncher >> doLogout [
    [
        | sessionToLogout |
        
        sessionToLogout := GbsSessionParameters allSessions 
            detect: [ :each | each name = 'Simple Launcher Session' ] 
            ifNone: [ GbsSessionParameters currentSession ].
            
        sessionToLogout ifNotNil: [ :s | s logout ].
        
        GbsSessionParameters currentSession: nil.
        
        "Sync ALL open Simple Launchers and Classic Launchers safely"
        UIManager default defer: [
            GbsLauncher allInstancesDo: [ :launcher | launcher updateUIState ].
            GbsClassicLauncher allInstancesDo: [ :launcher | launcher refreshAll ].
        ].
        
    ] on: Error do: [ :ex | self inform: 'Error logging out: ', ex messageText ].
]

{ #category : 'initialization' }
GbsLauncher >> initializePresenters [

  inputStone := self newTextInput.
  inputStone text: 'gs64stone'.
  
  inputUser := self newTextInput.
  inputUser text: 'DataCurator'.
  
  inputPass := self newTextInput.
  inputPass text: 'swordfish'.
  inputPass bePassword.
  
    inputLibPath := self newTextInput 
        text: '/Users/tariq/GemStone64Bit3.7.4.3-arm64.Darwin/lib/libgcirpc-3.7.4.3-64.dylib';
        placeholder: 'Path to libgcirpc.dylib'.

  btnLogin := self newButton.
  btnLogin label: 'Login'; icon: (self iconNamed: #smallOk).
  
  btnLogout := self newButton.
  btnLogout label: 'Logout'; icon: (self iconNamed: #smallCancel).

  btnWorkspace := self newButton.
  btnWorkspace label: 'Workspace'; icon: (self iconNamed: #smallWindow).
  
  btnBrowser := self newButton.
  btnBrowser label: 'Browser'; icon: (self iconNamed: #smallSystemBrowser).
  
  btnTranscript := self newButton.
  btnTranscript label: 'Transcript'; icon: (self iconNamed: #transcript).
  
  btnUsers := self newButton.
  btnUsers label: 'Users'; icon: (self iconNamed: #user).

  btnPolling := self newButton.
  btnPolling label: 'Toggle Polling'.

  statusLabel := self newLabel.
  statusLabel label: 'Status: Disconnected'.

  self updateUIState
]

{ #category : 'initialization' }
GbsLauncher >> initializeWindow: aWindowPresenter [
    aWindowPresenter 
        title: 'GemStone GBS Launcher';
        initialExtent: 350@400.
]

{ #category : 'polling' }
GbsLauncher >> startPolling [ 
    pollingProcess ifNotNil: [ pollingProcess terminate ].
    pollingProcess := [ 
        [ self window isNotNil and: [ self window isOpen ] ] whileTrue: [ 
            GbsSessionParameters pollingEnabled ifTrue: [ UIManager default defer: [ self updateUIState ] ].
            (Delay forSeconds: 2) wait.
        ] 
    ] fork.

]

{ #category : 'polling' }
GbsLauncher >> stopPolling [ 
    pollingProcess ifNotNil: [ pollingProcess terminate ].
    pollingProcess := nil.

]

{ #category : 'polling' }
GbsLauncher >> togglePollingPreference [
    GbsSessionParameters togglePolling.
    self updatePollingLabel.


]

{ #category : 'polling' }
GbsLauncher >> updatePollingLabel [ 
    btnPolling label: (GbsSessionParameters pollingEnabled ifTrue: [ 'Polling: On' ] ifFalse: [ 'Polling: Off' ]).

]

{ #category : 'updating' }
GbsLauncher >> updateUIState [
    | activeSession |
    "Check if our Simple Launcher Session is active globally"
    activeSession := GbsSessionParameters allSessions
        detect: [ :each | each name = 'Simple Launcher Session' ]
        ifNone: [ nil ].
        
    self updatePollingLabel.
    
    activeSession ifNotNil: [
        "We are logged in: Disable login, enable tools"
        statusLabel label: 'Status: Connected to ', activeSession gemStoneName.
        btnLogin disable.
        inputStone disable. inputUser disable. inputPass disable. inputLibPath disable.
        btnLogout enable.
        
        btnWorkspace enable. btnBrowser enable. btnTranscript enable. 
        btnUsers ifNotNil: [ btnUsers enable ]. "<-- NIL GUARD ADDED"
    ] ifNil: [
        "We are disconnected: Enable login, disable tools"
        statusLabel label: 'Status: Disconnected'.
        btnLogin enable.
        inputStone enable. inputUser enable. inputPass enable. inputLibPath enable.
        btnLogout disable.
        
        btnWorkspace disable. btnBrowser disable. btnTranscript disable. 
        btnUsers ifNotNil: [ btnUsers disable ]. "<-- NIL GUARD ADDED"
    ].
]
