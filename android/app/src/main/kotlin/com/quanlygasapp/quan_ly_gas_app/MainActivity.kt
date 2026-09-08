package com.quanlygasapp.quan_ly_gas_app

import io.flutter.embedding.android.FlutterFragmentActivity

// Phải kế thừa FlutterFragmentActivity (không phải FlutterActivity): plugin local_auth
// dùng BiometricPrompt của androidx.biometric, vốn yêu cầu Activity chủ là FragmentActivity.
// Nếu dùng FlutterActivity, mọi lần gọi authenticate() đều ném no_fragment_activity.
class MainActivity : FlutterFragmentActivity()
