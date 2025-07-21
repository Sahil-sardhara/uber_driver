import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class TripHistoryPage extends StatelessWidget {
  const TripHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String driverId = FirebaseAuth.instance.currentUser!.uid;
    final tripsRef = FirebaseDatabase.instance.ref().child('trips');

    return Scaffold(
      appBar: AppBar(title: const Text("Trip History")),
      body: StreamBuilder<DatabaseEvent>(
        stream: tripsRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("No trip history found."));
          }

          Map data = snapshot.data!.snapshot.value as Map;
          List trips =
              data.entries
                  .where((e) => e.value['driverId'] == driverId)
                  .map((e) => e.value)
                  .toList();

          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return ListTile(
                title: Text("${trip['pickup']} → ${trip['destination']}"),
                subtitle: Text("Date: ${trip['date']}"),
                trailing: Text("₹${trip['fare']}"),
              );
            },
          );
        },
      ),
    );
  }
}
