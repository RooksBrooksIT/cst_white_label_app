import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final TextEditingController _orgIdController = TextEditingController();
  bool _isMigrating = false;
  String _statusMessage = 'Awaiting migration...';

  // The collections that were previously at the root.
  final Map<String, String> collectionMappings = {
    'projects': 'projects',
    'Site': 'Site',
    'supervisor': 'supervisor',
    'supervisorDesignation': 'supervisorDesignation',
    'projectCategories': 'projectCategories',
    'projectStatus': 'projectStatus',
    'siteSupervisorMap': 'siteSupervisorMap',
    'totalSiteExpensesPerDay': 'totalSiteExpensesPerDay',
    'labours': 'labours',
    'materials': 'materials',
    'contractors': 'contractors',
    'materialCategories': 'materialCategories',
    'materialUnits': 'materialUnits',
    'materialSubCategories': 'materialSubCategories',
    'projectSubCategories': 'projectSubCategories',
    'configUser': 'manager', // Renamed collection
    // Other root collections that should be migrated
    'siteSupervisorEntries': 'siteSupervisorEntries',
    'managerExpenses': 'managerExpenses',
    'managerExpenseSummary': 'managerExpenseSummary',
    'organizationExpenseSummary': 'organizationExpenseSummary',
    'organizationEntries': 'organizationEntries',
    'contractorEntries': 'contractorEntries',
    'siteSupervisorIncentives': 'siteSupervisorIncentives',
    'siteDrawings': 'siteDrawings',
    'siteMaterialsRequest': 'siteMaterialsRequest',
    'projectStages': 'projectStages',
  };

  Future<void> _startMigration() async {
    final orgId = _orgIdController.text.trim();
    if (orgId.isEmpty) {
      setState(() => _statusMessage = 'Please enter a valid Target Org ID.');
      return;
    }

    setState(() {
      _isMigrating = true;
      _statusMessage = 'Starting migration to: organisation/$orgId/...';
    });

    final firestore = FirebaseFirestore.instance;
    final targetBase = firestore.collection('organisation').doc(orgId);

    int totalMigrated = 0;
    int totalErrors = 0;

    for (var entry in collectionMappings.entries) {
      final oldCollectionName = entry.key;
      final newCollectionName = entry.value;

      try {
        setState(() => _statusMessage = 'Migrating $oldCollectionName...');
        
        final oldSnapshot = await firestore.collection(oldCollectionName).get();
        if (oldSnapshot.docs.isEmpty) {
          debugPrint('No documents in $oldCollectionName. Skipping.');
          continue;
        }

        WriteBatch batch = firestore.batch();
        int batchCount = 0;

        for (var doc in oldSnapshot.docs) {
          final newDocRef = targetBase.collection(newCollectionName).doc(doc.id);
          batch.set(newDocRef, doc.data());
          batchCount++;

          // Commit in chunks if larger than 450 (Firestore transaction limit is 500)
          if (batchCount == 450) {
            await batch.commit();
            batchCount = 0;
            batch = firestore.batch(); // Re-instantiate batch for the next chunk
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }

        totalMigrated += oldSnapshot.docs.length;
        debugPrint('Successfully migrated ${oldSnapshot.docs.length} docs from $oldCollectionName to $newCollectionName.');
      } catch (e) {
        totalErrors++;
        debugPrint('Error migrating $oldCollectionName: $e');
      }
    }

    setState(() {
      _isMigrating = false;
      _statusMessage = 'Migration Complete! Migrated: $totalMigrated docs. Errors: $totalErrors. Note: Legacy root data was NOT deleted automatically, you must verify first, then delete them manually using Firebase Console.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Migration Utility')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Move Root Data to Organization',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This tool will copy all legacy root-level documents (e.g. /projects/, /Site/) into the new isolated structure: /organisation/{OrgID}/{collectionName}/.',
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _orgIdController,
              decoration: const InputDecoration(
                labelText: 'Target Organization ID',
                hintText: 'e.g. Hero_25-03-2026',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isMigrating ? null : _startMigration,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isMigrating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('MIGRATE DATA'),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.grey[200],
              child: Text(
                _statusMessage,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
