
import 'package:api_update/database/company_database_helper.dart';
import 'package:flutter/material.dart';

class CompanyPage extends StatefulWidget {
  @override
  CompanyPageState createState() => CompanyPageState();
}

class CompanyPageState extends State<CompanyPage> {
  final CompanyDatabaseHelper companyDatabaseHelper = CompanyDatabaseHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: companyDatabaseHelper.getPayload(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No data available'),
            );
          } else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Brand')),
                  DataColumn(label: Text('MerchandisingCategory')),
                  DataColumn(label: Text('Image')),
                  DataColumn(label: Text('BasePrice')),
                  DataColumn(label: Text('BaseUom')),
                  DataColumn(label: Text('IsBatchItem')),
                  DataColumn(label: Text('TaxId')),
                  DataColumn(label: Text('Delete')),
                ],
                rows: snapshot.data!.map((payload) {
                  return DataRow(cells: [
                    DataCell(Text('${payload['id']}')),
                    DataCell(Text('${payload['Code']}')),
                    DataCell(Text('${payload['Name']}')),
                    DataCell(Text('${payload['Description']}')),
                    DataCell(Text('${payload['Brand']}')),
                    DataCell(Text('${payload['MerchandisingCategory']}')),
                    DataCell(Text('${payload['Image']}')),
                    DataCell(Text('${payload['BasePrice']}')),
                    DataCell(Text('${payload['BaseUom']}')),
                    DataCell(Text('${payload['IsBatchItem']}')),
                    DataCell(Text('${payload['TaxId']}')),
                    DataCell(IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        _deleteEvent(payload['id']);
                      },
                    )),
                  ]);
                }).toList(),
              ),
            );
          }
        },
      ),
    );
  }
  Future<void> _deleteEvent(int eventId) async {
    await companyDatabaseHelper.deleteEvent(eventId);
    setState(() {}); // Update UI after deletion
  }
}
