import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String email = '';
  String password = '';
  String firstName = '';
  String lastName = '';
  DateTime? birthday;
  String gender = 'Male';
  String errorMessage = '';
  bool showSpinner = false;
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                textAlign: TextAlign.center,
                onChanged: (value) {
                  firstName = value;
                },
                decoration: InputDecoration(
                  hintText: 'Enter your first name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(32.0)),
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                textAlign: TextAlign.center,
                onChanged: (value) {
                  lastName = value;
                },
                decoration: InputDecoration(
                  hintText: 'Enter your last name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(32.0)),
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  email = value;
                },
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(32.0)),
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                obscureText: _obscureText,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  password = value;
                },
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(32.0)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                readOnly: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: birthday == null
                      ? 'Select your birthday'
                      : 'Birthday: ${birthday?.toLocal()}'.split(' ')[0],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(32.0)),
                  ),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null && pickedDate != birthday) {
                    setState(() {
                      birthday = pickedDate;
                    });
                  }
                },
              ),
              SizedBox(height: 8.0),
              DropdownButtonFormField<String>(
                value: gender,
                items: ['Male', 'Female', 'Other']
                    .map((label) => DropdownMenuItem(
                          child: Text(label),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    gender = value!;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(32.0)),
                  ),
                ),
              ),
              SizedBox(height: 24.0),
              showSpinner
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          showSpinner = true;
                          errorMessage = '';
                        });
                        try {
                          final newUser =
                              await _auth.createUserWithEmailAndPassword(
                                  email: email, password: password);
                          if (newUser != null) {
                            // Save user details to Firestore
                            await _firestore
                                .collection('users')
                                .doc(newUser.user?.uid)
                                .set({
                              'firstName': firstName,
                              'lastName': lastName,
                              'email': email,
                              'birthday': birthday?.toIso8601String(),
                              'gender': gender,
                              'profileImageUrl':
                                  '', // Initialize with empty string or a default value
                            });
                            Navigator.pop(context);
                          }
                        } on FirebaseAuthException catch (e) {
                          if (e.code == 'email-already-in-use') {
                            setState(() {
                              errorMessage =
                                  'The email address is already in use by another account.';
                            });
                          } else if (e.code == 'weak-password') {
                            setState(() {
                              errorMessage = 'The password is too weak.';
                            });
                          } else if (e.code == 'invalid-email') {
                            setState(() {
                              errorMessage = 'The email address is not valid.';
                            });
                          } else {
                            setState(() {
                              errorMessage = 'An unknown error occurred.';
                            });
                          }
                        } catch (e) {
                          setState(() {
                            errorMessage = e.toString();
                          });
                        }
                        setState(() {
                          showSpinner = false;
                        });
                      },
                      child: Text('Sign Up'),
                    ),
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
