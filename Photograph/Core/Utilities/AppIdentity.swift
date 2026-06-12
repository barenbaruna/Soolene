//
//  AppIdentity.swift
//  Visula
//
//  Display name, album name, and privacy purpose copy shown in Info.plist.
//

import Foundation

enum AppIdentity {
    static let displayName = "Visula"
    static let photoAlbumName = "Visula"

    enum Privacy {
        static let camera = """
        Visula uses the camera to show a live preview and provide real-time composition \
        guidance while you take photos.
        """

        static let photoLibraryAdd = """
        Visula saves photos you capture to your Photo Library and a Visula album so you \
        can review them in the app.
        """

        static let photoLibraryRead = """
        Visula accesses your Photo Library to display photos saved by Visula in your Library.
        """
    }
}
