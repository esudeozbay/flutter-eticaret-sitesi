import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişlerim'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('orders')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            // ignore: curly_braces_in_flow_control_structures
            return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text("Henüz siparişiniz yok."));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              final items = List<Map<String, dynamic>>.from(data['items']);

              return Card(
                margin: const EdgeInsets.all(12),
                child: ExpansionTile(
                  title: Text(
                    "Sipariş ${index + 1} - ${data['total'].toStringAsFixed(2)} ₺",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    data['timestamp'] != null
                        ? (data['timestamp'] as Timestamp).toDate().toString()
                        : '',
                  ),
                  children: items.map((item) {
                    return ListTile(
                      leading: Image.network(
                        item['imageUrl'],
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                      title: Text(item['name']),
                      trailing: Text('${item['price'].toStringAsFixed(2)} ₺'),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
