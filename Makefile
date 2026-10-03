SOURCES := ShuttleCore ShuttleScore

.PHONY: verify format lint build test project app

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

## app : build complet de l'app watchOS sur simulateur (lent, lancé en CI)
app: project
	xcodebuild build -project ShuttleScore.xcodeproj -scheme ShuttleScore \
		-destination 'generic/platform=watchOS Simulator' -quiet
