import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class EarningsPage extends StatelessWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String driverId = FirebaseAuth.instance.currentUser!.uid;
    final DatabaseReference earningsRef = FirebaseDatabase.instance
        .ref()
        .child('earnings')
        .child(driverId);

    return Scaffold(
      appBar: AppBar(title: const Text("Earnings")),
      body: FutureBuilder<DatabaseEvent>(
        future: earningsRef.once(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("No earnings data found."));
          }

          final earnings = snapshot.data!.snapshot.value;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Total Earnings", style: TextStyle(fontSize: 20)),
                const SizedBox(height: 10),
                Text(
                  "₹${earnings.toString()}",
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
