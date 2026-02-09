import SwiftUI

struct ContentView: View {
    @State private var kinect = KinectManager()
    
    var body: some View {
        VStack {
            HStack {
                if let colorFrame = kinect.colorFrame {
                    Image(colorFrame, scale: 1.0, label: Text("Color"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .overlay(Text("No Color Feed"))
                }
                
                if let depthFrame = kinect.depthFrame {
                    Image(depthFrame, scale: 1.0, label: Text("Depth"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .overlay(Text("No Depth Feed"))
                }
            }
            
            HStack {
                Button(kinect.isConnected ? "Disconnect" : "Connect") {
                    Task {
                        if kinect.isConnected {
                            kinect.disconnect()
                        } else {
                            try? await kinect.connect()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Text("Serial: \(kinect.serialNumber)")
                    .font(.caption)
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}
