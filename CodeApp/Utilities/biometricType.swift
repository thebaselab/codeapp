//
//  biometricType.swift
//  Code
//
//  Created by Ken Chung on 14/4/2022.
//

import LocalAuthentication

func biometricAuthSupported() -> Bool {
    let authContext = LAContext()
    return authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
}
