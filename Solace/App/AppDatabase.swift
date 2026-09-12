//
//  AppDatabase.swift
//  Solace
//

import Dependencies
import Foundation
import OSLog
import SQLiteData

nonisolated private let logger = Logger(subsystem: "com.nandanvarma.Solace", category: "Database")

extension DependencyValues {
    /// Creates/migrates the local database and wires the CloudKit `SyncEngine`
    /// for the three user-data tables. Reference caches (`CachedProduct`,
    /// `CachedGenericFood`) are deliberately excluded from sync.
    mutating func bootstrapDatabase() throws {
        @Dependency(\.context) var context
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.attachMetadatabase()
            #if DEBUG
                db.trace(options: .profile) {
                    guard !SyncEngine.isSynchronizing else { return }
                    switch context {
                    case .live: logger.debug("\($0.expandedDescription)")
                    case .preview: print("\($0.expandedDescription)")
                    case .test: break
                    }
                }
            #endif
        }
        var migrator = DatabaseMigrator()
        #if DEBUG
            migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("Create tables") { db in
            try #sql(
                """
                CREATE TABLE "cachedProducts" (
                  "barcode" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT,
                  "brands" TEXT,
                  "nutriscoreGrade" TEXT,
                  "nutriscoreVersion" TEXT,
                  "novaGroup" INTEGER,
                  "ecoScoreGrade" TEXT,
                  "energyKcal100g" REAL,
                  "proteins100g" REAL,
                  "carbohydrates100g" REAL,
                  "sugars100g" REAL,
                  "fat100g" REAL,
                  "saturatedFat100g" REAL,
                  "fiber100g" REAL,
                  "sodium100g" REAL,
                  "allergensTagsJSON" TEXT NOT NULL DEFAULT '[]',
                  "ingredientsText" TEXT,
                  "imageURL" TEXT,
                  "fetchedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "cachedGenericFoods" (
                  "fdcId" INTEGER PRIMARY KEY NOT NULL,
                  "description" TEXT NOT NULL,
                  "dataType" TEXT NOT NULL,
                  "energyKcal100g" REAL,
                  "proteins100g" REAL,
                  "carbohydrates100g" REAL,
                  "fat100g" REAL,
                  "fiber100g" REAL,
                  "sodium100g" REAL,
                  "fetchedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "userProfiles" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "sex" TEXT,
                  "birthYear" INTEGER,
                  "heightCm" REAL,
                  "weightKg" REAL,
                  "activityLevel" TEXT,
                  "dailyCalorieTargetOverride" INTEGER,
                  "allergenExclusionsJSON" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                  "dietaryFlagsJSON" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                  "nutriScoreWeight" REAL NOT NULL ON CONFLICT REPLACE DEFAULT 0.40,
                  "novaWeight" REAL NOT NULL ON CONFLICT REPLACE DEFAULT 0.25,
                  "ecoScoreWeight" REAL NOT NULL ON CONFLICT REPLACE DEFAULT 0.15,
                  "personalGoalWeight" REAL NOT NULL ON CONFLICT REPLACE DEFAULT 0.20,
                  "healthKitSyncEnabled" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                  "onDeviceAIEnabled" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 1
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "aiProviderSettings" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "isEnabled" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                  "baseURL" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'https://api.openai.com/v1',
                  "modelString" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT ''
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "diaryEntries" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "loggedAt" TEXT NOT NULL,
                  "mealSlot" TEXT NOT NULL,
                  "sourceKind" TEXT NOT NULL,
                  "sourceBarcode" TEXT,
                  "sourceFdcId" INTEGER,
                  "photoEstimateLabel" TEXT,
                  "photoEstimateConfidence" REAL,
                  "quantityGrams" REAL NOT NULL,
                  "energyKcal" REAL NOT NULL,
                  "proteinsG" REAL NOT NULL,
                  "carbohydratesG" REAL NOT NULL,
                  "fatG" REAL NOT NULL,
                  "healthKitSampleUUID" TEXT
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE INDEX "idx_diaryEntries_loggedAt" ON "diaryEntries"("loggedAt")
                """
            )
            .execute(db)
        }

        // An unopenable/corrupt database file would otherwise crash at
        // every launch with no recovery path. Since the three synced tables
        // repopulate from CloudKit, it's safe to fall back to a fresh local
        // database rather than abort.
        let database: any DatabaseWriter
        do {
            let opened = try SQLiteData.defaultDatabase(configuration: configuration)
            try migrator.migrate(opened)
            database = opened
        } catch {
            logger.error("failed to open/migrate database, resetting local file: \(error)")
            try deleteDefaultDatabaseFile()
            let opened = try SQLiteData.defaultDatabase(configuration: configuration)
            try migrator.migrate(opened)
            database = opened
        }
        logger.info("open '\(database.path)'")

        defaultDatabase = database
        defaultSyncEngine = try SyncEngine(
            for: database,
            tables: UserProfile.self, AIProviderSettings.self, DiaryEntry.self
        )
    }
}

/// Removes the on-disk database file (and its WAL/SHM siblings) so a corrupt
/// file doesn't wedge every future launch. Only relevant in a live app
/// context — previews/tests use in-memory or temporary databases.
private func deleteDefaultDatabaseFile() throws {
    @Dependency(\.context) var context
    guard context == .live else { return }
    let directory = try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    )
    let base = directory.appendingPathComponent("SQLiteData.db")
    for suffix in ["", "-wal", "-shm"] {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: base.path + suffix))
    }
}
