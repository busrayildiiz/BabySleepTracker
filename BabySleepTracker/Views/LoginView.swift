//
//  LoginView.swift
//  BabySleepTracker
//
//  Created by MacBook on 6.06.2026.
//

import Foundation
import SwiftUI

struct LogInView: View {
    @Binding var authState: AuthState

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Nav
                    HStack {
                        Button { authState = .landing } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "6B63D8"))
                                .frame(width: 36, height: 36)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    ScrollView {
                        VStack(spacing: 28) {
                            Text("🌙").font(.system(size: 60)).padding(.top, 8)

                            VStack(spacing: 8) {
                                Text("Welcome Back")
                                    .font(.title2.weight(.bold))
                                Text("Sign in to continue tracking\nyour baby's sleep.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            VStack(spacing: 14) {
                                // Email
                                fieldView(icon: "envelope", placeholder: "Email",
                                          text: $email, error: $emailError, secure: false)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)

                                // Password
                                ZStack(alignment: .trailing) {
                                    fieldView(icon: "lock", placeholder: "Password",
                                              text: $password, error: $passwordError,
                                              secure: !showPassword)
                                    Button { showPassword.toggle() } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundStyle(.secondary)
                                            .padding(.trailing, 14)
                                    }
                                }

                                HStack {
                                    Spacer()
                                    Button {
                                        // Forgot password — V2
                                    } label: {
                                        Text("Forgot Password?")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color(hex: "6B63D8"))
                                    }
                                }
                            }

                            Button {
                                validateAndLogin()
                            } label: {
                                Text("Log In")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(hex: "6B63D8"))
                                    )
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button { authState = .creatingAccount } label: {
                                    Text("Sign Up")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color(hex: "6B63D8"))
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func fieldView(icon: String, placeholder: String,
                           text: Binding<String>, error: Binding<String?>,
                           secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(Color(hex: "6B63D8").opacity(0.6))
                    .frame(width: 20)
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .onChange(of: text.wrappedValue) { _ in error.wrappedValue = nil }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(error.wrappedValue != nil ? Color.red : Color.primary.opacity(0.1), lineWidth: 1)
            )

            if let err = error.wrappedValue {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill").font(.caption)
                    Text(err).font(.caption)
                }
                .foregroundStyle(.red)
            }
        }
    }

    private func validateAndLogin() {
        var valid = true
        if !email.contains("@") || !email.contains(".") {
            emailError = "Please enter a valid email."
            valid = false
        }
        if password.count < 6 {
            passwordError = "Password must be at least 6 characters."
            valid = false
        }
        if valid {
            UserDefaults.standard.set(true, forKey: "authComplete")
            authState = .loggedIn
        }
    }
}
