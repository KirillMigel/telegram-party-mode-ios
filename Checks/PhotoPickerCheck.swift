import Foundation
import CoreGraphics

@main struct PhotoPickerCheck {
    static func main() {
        for (width, height, top, bottom): (CGFloat, CGFloat, CGFloat, CGFloat) in [
            (320, 568, 20, 0), (375, 812, 44, 34), (402, 874, 62, 34), (430, 932, 62, 34)
        ] {
            let source = CGRect(x: (width-68)/2, y: top+92, width: 68, height: 68)
            let target = PhotoPickerMorph.destination(source: source, width: width, height: height, top: top, bottom: bottom)
            assert(target.minX >= 16 && target.maxX <= width-16)
            assert(target.minY >= top+60 && target.maxY <= height-bottom-16)
            let cell = (target.width-16)/3
            assert(abs(target.height-(12+cell*2+2)) < 0.001, "The glass panel fits two photo rows without empty space")
            assert(PhotoPickerMorph.frame(source: source, target: target, progress: 0) == source)
            assert(PhotoPickerMorph.frame(source: source, target: target, progress: 1) == target)
            let middle = PhotoPickerMorph.frame(source: source, target: target, progress: 0.5)
            assert(middle.width > (source.width+target.width)/2, "Glass inflates sideways before the photo surface unfolds")
            assert(middle.height < (source.height+target.height)/2)
            let spring = CriticalSpring(start: .zero, target: MotionVector(progress: 1), velocity: .zero,
                                        startedAt: 0, response: 0.5, dampingRatio: 0.8)
            for frame in 0...144 {
                let p = spring.sample(at: Double(frame)/120).value.progress
                let rect = PhotoPickerMorph.frame(source: source, target: target, progress: p)
                assert(rect.width > 0 && rect.height > 0 && rect.midX.isFinite && rect.midY.isFinite)
                assert(rect.minX > 0 && rect.maxX < width && rect.minY > 0 && rect.maxY < height)
            }
        }
        print("PASS: exact portal origin, panel destination, phone-size bounds, finite spring overshoot")
    }
}
