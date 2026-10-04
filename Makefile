SOURCES := ShuttleCore ShuttleScore ShuttleScoreUITests
# Premier simulateur Apple Watch Ultra disponible (sinon n'importe quelle Apple Watch).
SIM_LIST := xcrun simctl list devices available
WATCH_SIM ?= $(or $(shell $(SIM_LIST) | grep 'Apple Watch Ultra' | head -1 | grep -oE '[0-9A-F-]{36}'),$(shell $(SIM_LIST) | grep 'Apple Watch' | head -1 | grep -oE '[0-9A-F-]{36}'))

.PHONY: verify format lint build test project app ui-test

## verify : format + lint + typecheck + tests du domaine (< 1 min). À lancer avant chaque fin de tâche.
verify: lint build test

## format : reformate le code en place
format:
	swift format format --in-place --recursive $(SOURCES)

lint:
	swift format lint --strict --recursive $(SOURCES)

build:
	cd ShuttleCore && swift build -Xswiftc -warnings-as-errors

test:
	cd ShuttleCore && swift test -Xswiftc -warnings-as-errors

## project : génère ShuttleScore.xcodeproj depuis project.yml
project:
	xcodegen generate

## app : build complet de l'app watchOS sur simulateur (lent, lancé en CI),
## puis vérifie le mode arrière-plan « workout » sans lequel la séance ne garde pas l'app active.
APP_PLIST := .build/xcode/Build/Products/Debug-watchsimulator/ShuttleScore.app/Info.plist
app: project
	xcodebuild build -project ShuttleScore.xcodeproj -scheme ShuttleScore \
		-destination 'generic/platform=watchOS Simulator' -derivedDataPath .build/xcode -quiet
	@plutil -extract WKBackgroundModes json -o - $(APP_PLIST) | grep -q workout-processing \
		|| (echo "Info.plist : WKBackgroundModes doit contenir workout-processing" && exit 1)

## ui-test : tests de bout en bout sur simulateur watchOS (lent, lancé en CI)
ui-test: project
	xcodebuild test -project ShuttleScore.xcodeproj -scheme ShuttleScore \
		-destination 'id=$(WATCH_SIM)' -quiet
