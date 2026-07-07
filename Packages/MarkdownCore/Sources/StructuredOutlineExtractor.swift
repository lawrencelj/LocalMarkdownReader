import Foundation

enum StructuredOutlineExtractor {
    private static let maximumDepth = 6
    private static let maximumItems = 500

    static func extract(from content: String, format: DocumentFormat) -> [HeadingItem] {
        switch format {
        case .json:
            return extractJSON(from: content)
        case .xml:
            return extractXML(from: content)
        default:
            return []
        }
    }

    private static func extractJSON(from content: String) -> [HeadingItem] {
        guard let data = content.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
              ) else {
            return []
        }

        var items: [HeadingItem] = []
        appendJSONValue(value, name: "Root", level: 1, to: &items)
        return items
    }

    private static func appendJSONValue(
        _ value: Any,
        name: String,
        level: Int,
        to items: inout [HeadingItem]
    ) {
        guard level <= maximumDepth, items.count < maximumItems else { return }

        let typeDescription: String
        if let object = value as? [String: Any] {
            typeDescription = "object"
            items.append(outlineItem(level: level, title: "\(name): \(typeDescription)"))
            for key in object.keys.sorted() {
                guard let child = object[key] else { continue }
                appendJSONValue(child, name: key, level: level + 1, to: &items)
            }
            return
        } else if let array = value as? [Any] {
            typeDescription = "array [\(array.count)]"
            items.append(outlineItem(level: level, title: "\(name): \(typeDescription)"))
            if let first = array.first {
                appendJSONValue(first, name: "items", level: level + 1, to: &items)
            }
            return
        } else if value is NSNull {
            typeDescription = "null"
        } else if value is String {
            typeDescription = "string"
        } else if value is Bool {
            typeDescription = "boolean"
        } else if value is NSNumber {
            typeDescription = "number"
        } else {
            typeDescription = "value"
        }

        items.append(outlineItem(level: level, title: "\(name): \(typeDescription)"))
    }

    private static func extractXML(from content: String) -> [HeadingItem] {
        guard let data = content.data(using: .utf8) else { return [] }

        let delegate = XMLStructureParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return [] }

        var items: [HeadingItem] = []
        for root in delegate.roots {
            appendXMLNode(root, level: 1, to: &items)
        }
        return items
    }

    private static func appendXMLNode(
        _ node: XMLStructureNode,
        level: Int,
        to items: inout [HeadingItem]
    ) {
        guard level <= maximumDepth, items.count < maximumItems else { return }

        items.append(outlineItem(level: level, title: node.name))
        for attribute in node.attributes.sorted() {
            guard items.count < maximumItems else { return }
            items.append(outlineItem(level: level + 1, title: "@\(attribute)"))
        }
        for child in node.children {
            appendXMLNode(child, level: level + 1, to: &items)
        }
    }

    private static func outlineItem(level: Int, title: String) -> HeadingItem {
        HeadingItem(
            level: level,
            title: title,
            range: NSRange(location: 0, length: 0),
            position: 0
        )
    }
}

private final class XMLStructureNode {
    let name: String
    var attributes: Set<String>
    var children: [XMLStructureNode] = []

    init(name: String, attributes: Set<String>) {
        self.name = name
        self.attributes = attributes
    }

    func child(named name: String, attributes: Set<String>) -> XMLStructureNode {
        if let existing = children.first(where: { $0.name == name }) {
            existing.attributes.formUnion(attributes)
            return existing
        }

        let child = XMLStructureNode(name: name, attributes: attributes)
        children.append(child)
        return child
    }
}

private final class XMLStructureParserDelegate: NSObject, XMLParserDelegate {
    var roots: [XMLStructureNode] = []
    private var stack: [XMLStructureNode] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let attributes = Set(attributeDict.keys)
        let node: XMLStructureNode

        if let parent = stack.last {
            node = parent.child(named: elementName, attributes: attributes)
        } else if let existing = roots.first(where: { $0.name == elementName }) {
            existing.attributes.formUnion(attributes)
            node = existing
        } else {
            node = XMLStructureNode(name: elementName, attributes: attributes)
            roots.append(node)
        }

        stack.append(node)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if !stack.isEmpty {
            stack.removeLast()
        }
    }
}
