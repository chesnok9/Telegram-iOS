import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

private let titleFont = Font.regular(40.0)
private let subtitleFont: UIFont = {
    if #available(iOS 8.2, *) {
        return UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.bold)
    } else {
        return CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 12.0, nil)
    }
}()

private func generateButtonImage(background: PasscodeBackground, frame: CGRect, title: String, subtitle: String, highlighted: Bool) -> UIImage? {
    return generateImage(frame.size, contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let relativeFrame = CGRect(x: -frame.minX, y: frame.minY - background.size.height + frame.size.height
            , width: background.size.width, height: background.size.height)
        
        context.beginPath()
        context.addEllipse(in: bounds)
        context.clip()
        
        context.setAlpha(0.8)
        context.draw(background.foregroundImage.cgImage!, in: relativeFrame)
        
        if highlighted {
            context.setFillColor(UIColor(white: 1.0, alpha: 0.65).cgColor)
            context.fillEllipse(in: bounds)
        }
        
        context.setAlpha(1.0)
        context.textMatrix = .identity
        
        var offset: CGFloat = -11.0
        if subtitle.isEmpty {
            offset -= 7.0
        }
        
        let titlePath = CGMutablePath()
        titlePath.addRect(bounds.offsetBy(dx: 0.0, dy: offset))
        let titleString = NSAttributedString(string: title, font: titleFont, textColor: .white, paragraphAlignment: .center)
        let titleFramesetter = CTFramesetterCreateWithAttributedString(titleString as CFAttributedString)
        let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, titleString.length), titlePath, nil)
        CTFrameDraw(titleFrame, context)
        
        if !subtitle.isEmpty {
            let subtitlePath = CGMutablePath()
            subtitlePath.addRect(bounds.offsetBy(dx: 0.0, dy: -54.0))
            let subtitleString = NSAttributedString(string: subtitle, font: subtitleFont, textColor: .white, paragraphAlignment: .center)
            let subtitleFramesetter = CTFramesetterCreateWithAttributedString(subtitleString as CFAttributedString)
            let subtitleFrame = CTFramesetterCreateFrame(subtitleFramesetter, CFRangeMake(0, subtitleString.length), subtitlePath, nil)
            CTFrameDraw(subtitleFrame, context)
        }
    })
}

final class PasscodeEntryButtonNode: HighlightTrackingButtonNode {
    private var background: PasscodeBackground
    let title: String
    private let subtitle: String
    
    private var currentImage: UIImage?
    private var regularImage: UIImage?
    private var highlightedImage: UIImage?
    
    private let backgroundNode: ASImageNode
    
    init(background: PasscodeBackground, title: String, subtitle: String) {
        self.background = background
        self.title = title
        self.subtitle = subtitle
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                strongSelf.updateState(highlighted: highlighted)
            }
        }
    }
    
    override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            self.updateGraphics()
        }
    }
    
    func updateBackground(_ background: PasscodeBackground) {
        self.background = background
        self.updateGraphics()
    }
    
    private func updateGraphics() {
        self.regularImage = generateButtonImage(background: self.background, frame: self.frame, title: self.title, subtitle: self.subtitle, highlighted: false)
        self.highlightedImage = generateButtonImage(background: self.background, frame: self.frame, title: self.title, subtitle: self.subtitle, highlighted: true)
        self.updateState(highlighted: self.isHighlighted)
    }
    
    private func updateState(highlighted: Bool) {
        let image = highlighted ? self.highlightedImage : self.regularImage
        if self.currentImage !== image {
            let currentContents = self.backgroundNode.layer.contents
            self.backgroundNode.layer.removeAnimation(forKey: "contents")
            if let currentContents = currentContents, let image = image {
                self.backgroundNode.image = image
                self.backgroundNode.layer.animate(from: currentContents as AnyObject, to: image.cgImage!, keyPath: "contents", timingFunction: kCAMediaTimingFunctionEaseOut, duration: image === self.regularImage ? 0.45 : 0.05)
            } else {
                self.backgroundNode.image = image
            }
            self.currentImage = image
        }
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
    }
}

private let buttonsData = [
    ("1", " "),
    ("2", "A B C"),
    ("3", "D E F"),
    ("4", "G H I"),
    ("5", "J K L"),
    ("6", "M N O"),
    ("7", "P Q R S"),
    ("8", "T U V"),
    ("9", "W X Y Z"),
    ("0", "")
]

final class PasscodeEntryKeyboardNode: ASDisplayNode {
    private var background: PasscodeBackground?
    
    var charactedEntered: ((String) -> Void)?
    
    private func updateButtons() {
        guard let background = self.background else {
            return
        }
        
        if let subnodes = self.subnodes, !subnodes.isEmpty {
            for case let button as PasscodeEntryButtonNode in subnodes {
                button.updateBackground(background)
            }
        } else {
            for (title, subtitle) in buttonsData {
                let buttonNode = PasscodeEntryButtonNode(background: background, title: title, subtitle: subtitle)
                buttonNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchDown)
                self.addSubnode(buttonNode)
            }
        }
    }
    
    func updateBackground(_ background: PasscodeBackground) {
        self.background = background
        self.updateButtons()
    }
    
    @objc private func buttonPressed(_ sender: PasscodeEntryButtonNode) {
        self.charactedEntered?(sender.title)
    }
    
    func animateIn() {
        if let subnodes = self.subnodes {
            for i in 0 ..< subnodes.count {
                let subnode = subnodes[i]
                var delay: Double = 0.0
                if i / 3 == 1 {
                    delay = 0.05
                }
                else if i / 3 == 2 {
                    delay = 0.1
                }
                else if i / 3 == 3 {
                    delay = 0.15
                }
                subnode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: delay, timingFunction: kCAMediaTimingFunctionEaseOut)
            }
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGRect {
        let buttonSize: CGFloat
        let horizontalSecond: CGFloat
        let horizontalThird: CGFloat
        let verticalSecond: CGFloat
        let verticalThird: CGFloat
        let verticalFourth: CGFloat
        let size: CGSize
        let offset: CGFloat
        
        let height = Int(max(layout.size.width, layout.size.height))
        switch height {
            case 1024, 1194, 1366:
                buttonSize = 81.0
                horizontalSecond = 106.0
                horizontalThird = 212.0
                verticalSecond = 100.0 + UIScreenPixel
                verticalThird = 202.0
                verticalFourth = 303.0
                size = CGSize(width: 293.0, height: 384.0)
                offset = 0.0
            case 896:
                buttonSize = 85.0
                horizontalSecond = 115.0
                horizontalThird = 230.0
                verticalSecond = 100.0
                verticalThird = 200.0
                verticalFourth = 300.0
                size = CGSize(width: 315.0, height: 385.0)
                offset = 240.0
            case 812:
                buttonSize = 85.0
                horizontalSecond = 115.0
                horizontalThird = 230.0
                verticalSecond = 100.0
                verticalThird = 200.0
                verticalFourth = 300.0
                size = CGSize(width: 315.0, height: 385.0)
                offset = 240.0
            case 736:
                buttonSize = 75.0
                horizontalSecond = 103.5
                horizontalThird = 206.0
                verticalSecond = 90.0
                verticalThird = 180.0
                verticalFourth = 270.0
                size = CGSize(width: 281.0, height: 345.0)
                offset = 0.0
            case 667:
                buttonSize = 75.0
                horizontalSecond = 103.5
                horizontalThird = 206.0
                verticalSecond = 90.0
                verticalThird = 180.0
                verticalFourth = 270.0
                size = CGSize(width: 281.0, height: 345.0)
                offset = 0.0
            case 568:
                buttonSize = 75.0
                horizontalSecond = 95.0
                horizontalThird = 190.0
                verticalSecond = 88.0
                verticalThird = 176.0
                verticalFourth = 264.0
                size = CGSize(width: 265.0, height: 339.0)
                offset = 0.0
            default:
                buttonSize = 75.0
                horizontalSecond = 95.0
                horizontalThird = 190.0
                verticalSecond = 88.0
                verticalThird = 176.0
                verticalFourth = 264.0
                size = CGSize(width: 265.0, height: 339.0)
                offset = 0.0
        }
        
        let origin = CGPoint(x: floor((layout.size.width - size.width) / 2.0), y: offset)
        
        if let subnodes = self.subnodes {
            for i in 0 ..< subnodes.count {
                var origin = origin
                if i % 3 == 0 {
                    origin.x += 0.0
                } else if (i % 3 == 1) {
                    origin.x += horizontalSecond
                }
                else {
                    origin.x += horizontalThird
                }
                
                if i / 3 == 0 {
                    origin.y += 0.0
                }
                else if i / 3 == 1 {
                    origin.y += verticalSecond
                }
                else if i / 3 == 2 {
                    origin.y += verticalThird
                }
                else if i / 3 == 3 {
                    origin.x += horizontalSecond
                    origin.y += verticalFourth
                }
                transition.updateFrame(node: subnodes[i], frame: CGRect(origin: origin, size: CGSize(width: buttonSize, height: buttonSize)))
            }
        }
        return CGRect(origin: origin, size: size)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let result = result, result.isDescendant(of: self.view) {
            return result
        }
        return nil
    }
}
