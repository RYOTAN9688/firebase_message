// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider, PhoneAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'guest_book_message.dart';

enum Attending { yes, no, unknown }

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  StreamSubscription<QuerySnapshot>? _guestBookSubscription;
  List<GuestBookMessage> _guestBookMessage = [];
  List<GuestBookMessage> get guestBookMessage => _guestBookMessage;

  Future<void> init() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
    ]);

    FirebaseFirestore.instance.collection('attendees').where('attending', isEqualTo: true).snapshots().listen(
      (snapshot) {
        _attendees = snapshot.docs.length;
        notifyListeners();
      },
    );

    FirebaseAuth.instance.userChanges().listen(
      (user) {
        if (user != null) {
          _loggedIn = true;
          _guestBookSubscription = FirebaseFirestore.instance
              .collection('guestbook')
              .orderBy(
                'timestamp',
                descending: true,
              )
              .snapshots()
              .listen((snapshot) {
            _guestBookMessage = [];
            for (final document in snapshot.docs) {
              _guestBookMessage.add(
                GuestBookMessage(
                  name: document.data()['name'].toString(),
                  message: document.data()['text'].toString(),
                ),
              );
            }
            _attendingSubscription = FirebaseFirestore.instance.collection('attendees').doc(user.uid).snapshots().listen(
              (snapshot) {
                if (snapshot.data() != null) {
                  if (snapshot.data()!['attending'] as bool) {
                    _atteing = Attending.yes;
                  } else {
                    _atteing = Attending.no;
                  }
                } else {
                  _atteing = Attending.unknown;
                }
                notifyListeners();
              },
            );
            notifyListeners();
          });
        } else {
          _loggedIn = false;
          _guestBookMessage = [];
          _guestBookSubscription?.cancel();
          _attendingSubscription?.cancel();
        }
        notifyListeners();
      },
    );
  }

  Future<DocumentReference> addMessageToGuestBook(String message) {
    if (!_loggedIn) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance.collection('guestbook').add(<String, dynamic>{
      'text': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'name': FirebaseAuth.instance.currentUser!.displayName,
      'userId': FirebaseAuth.instance.currentUser!.uid,
    });
  }

  int _attendees = 0;
  int get attendees => _attendees;

  Attending _atteing = Attending.unknown;
  StreamSubscription<DocumentSnapshot>? _attendingSubscription;
  Attending get attending => _atteing;
  set attending(Attending attending) {
    final userDoc = FirebaseFirestore.instance.collection('attendees').doc(FirebaseAuth.instance.currentUser!.uid);
    if (attending == Attending.yes) {
      userDoc.set(<String, dynamic>{'attending': true});
    } else {
      userDoc.set(<String, dynamic>{'attending': false});
    }
  }
}
