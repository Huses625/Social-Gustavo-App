const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendMessageNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const chatId = context.params.chatId;

    // Get the recipient's user ID from the chat document
    const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
    const participants = chatDoc.data().participants;

    // Assume the senderId is the current user's ID
    const senderId = message.senderId;
    const receiverId = participants.find(participant => participant !== senderId);

    // Get the receiver's FCM token
    const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
    const fcmToken = receiverDoc.data().fcmToken;

    if (!fcmToken) {
      console.log('No FCM token for user', receiverId);
      return null;
    }

    const payload = {
      notification: {
        title: `${message.senderName} sent you a message`,
        body: message.content,
        sound: 'default',
      },
      data: {
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
      },
    };

    try {
      await admin.messaging().sendToDevice(fcmToken, payload);
      console.log('Notification sent successfully');
    } catch (error) {
      console.error('Error sending notification', error);
    }

    return null;
  });
