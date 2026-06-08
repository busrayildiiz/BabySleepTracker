//
//  LandingView.swift
//  BabySleepTracker
//
//  Created by MacBook on 6.06.2026.
//

import Foundation
import SwiftUI

struct LandingView: View {
    @Binding var authState: AuthState

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "EEF0FF"), Color(hex: "F8F0FF")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Stars decoration
            starsDecoration

            VStack(spacing: 0) {
                // Moon illustration
                Spacer()
                moonIllustration
                    .padding(.top, 60)

                // Title
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Text("Baby")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color(hex: "1A1A2E"))
                        Text("Sleep")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color(hex: "6B63D8"))
                        Text("Tracker")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color(hex: "1A1A2E"))
                    }

                    VStack(spacing: 4) {
                        Text("Understand your baby's sleep.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text("Empower")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: "6B63D8"))
                            Text("every day.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Page dots
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "6B63D8")).frame(width: 8, height: 8)
                        Circle().fill(Color(hex: "6B63D8").opacity(0.3)).frame(width: 8, height: 8)
                    }
                    .padding(.top, 4)
                }

                Spacer()

                // Bottom sheet
                VStack(spacing: 12) {
                    // Continue with Email
                    Button { authState = .creatingAccount } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16))
                            Text("Continue with Email")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(hex: "6B63D8"))
                        )
                    }
                    .buttonStyle(.plain)

                    // Continue with Apple
                    Button { authState = .loggedIn } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .medium))
                            Text("Continue with Apple")
                                .font(.headline)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    // Continue with Google
                    Button { authState = .loggedIn } label: {
                        HStack(spacing: 12) {
                            Text("G")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange, .yellow, .green, .blue],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            Text("Continue with Google")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                        Text("or").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                        Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                    }

                    // Create Account
                    Button { authState = .creatingAccount } label: {
                        Text("Create an Account")
                            .font(.headline)
                            .foregroundStyle(Color(hex: "6B63D8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(hex: "6B63D8").opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)

                    // Log in
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button { authState = .loggingIn } label: {
                            Text("Log In")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: "6B63D8"))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 40)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color(.systemGroupedBackground))
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
    }

    // MARK: - Moon illustration

    private var moonIllustration: some View {
        ZStack {
            // Stars
            Text("⭐️").font(.system(size: 28)).offset(x: -90, y: -20)
            Text("⭐️").font(.system(size: 36)).offset(x: 100, y: -40)
            Text("✦").font(.system(size: 14)).foregroundStyle(Color(hex: "6B63D8").opacity(0.4)).offset(x: 60, y: 20)
            Text("✦").font(.system(size: 10)).foregroundStyle(Color(hex: "6B63D8").opacity(0.3)).offset(x: -60, y: 30)
            Text("✦").font(.system(size: 8)).foregroundStyle(Color(hex: "6B63D8").opacity(0.25)).offset(x: 120, y: 30)

            // Moon + Cloud
            VStack(spacing: -20) {
                Text("🌙")
                    .font(.system(size: 130))
                    .scaleEffect(x: -1) // flip
                HStack(spacing: -20) {
                    Text("☁️").font(.system(size: 70)).opacity(0.7)
                    Text("☁️").font(.system(size: 90)).opacity(0.5)
                }
            }
        }
        .frame(height: 260)
    }

    // MARK: - Stars

    private var starsDecoration: some View {
        ZStack {
            Text("✦").font(.system(size: 12))
                .foregroundStyle(Color(hex: "6B63D8").opacity(0.2))
                .position(x: 40, y: 120)
            Text("✦").font(.system(size: 8))
                .foregroundStyle(Color(hex: "6B63D8").opacity(0.15))
                .position(x: 340, y: 160)
            Text("✦").font(.system(size: 10))
                .foregroundStyle(Color(hex: "6B63D8").opacity(0.18))
                .position(x: 60, y: 300)
        }
    }
}
