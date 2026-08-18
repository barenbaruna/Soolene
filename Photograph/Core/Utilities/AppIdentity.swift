//
//  AppIdentity.swift
//  Soolene
//
//  Display name, album name, and privacy purpose copy shown in Info.plist.
//

import Foundation

enum AppIdentity {
    static let displayName = "Soolene"
    static let photoAlbumName = "Soolene"

    enum Privacy {
        static let camera = """
        Soolene uses the camera to show a live viewfinder and guide your composition while you shoot.
        """

        static let photoLibraryAdd = """
        Soolene saves your captures to your Photo Library so you can review guided shots in the app.
        """

        static let photoLibraryRead = """
        Soolene accesses your Photo Library to show the guided shots you save in the app.
        """
    }
}
