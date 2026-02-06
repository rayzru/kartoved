# ML/AI Engineer - Machine Learning Specialist

**Role:** Machine Learning & Computer Vision Engineer
**Expertise:** OCR, on-device ML, model optimization
**Experience:** 6+ years ML/AI, TensorFlow Lite, Core ML

---

## Картовед ML Requirements

### OCR for Bank Screenshots (70%+ accuracy target)

**Hybrid Approach:**
- 90% on-device (ML Kit, Vision Framework) - free, instant
- 10% cloud fallback (AWS Textract) - $1.50/1K pages, high accuracy

### On-Device OCR (iOS)

```swift
// ios/Kartoved/Services/OCRService.swift
import Vision
import UIKit

class OCRService {
    func recognizeText(from image: UIImage, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])))
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.success([]))
                return
            }

            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            completion(.success(recognizedStrings))
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ru-RU", "en-US"]
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }

    func extractCashbackCategories(from text: [String]) -> [CashbackCategory] {
        var categories: [CashbackCategory] = []

        let pattern = #"([\d.,]+)\s*%\s*.*?(продукт|кафе|рестора|азс|такси|аптек|одежд)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        for line in text {
            let nsString = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                if match.numberOfRanges >= 3 {
                    let percentRange = match.range(at: 1)
                    let categoryRange = match.range(at: 2)

                    let percentString = nsString.substring(with: percentRange).replacingOccurrences(of: ",", with: ".")
                    let categoryHint = nsString.substring(with: categoryRange).lowercased()

                    if let percent = Double(percentString) {
                        let mccCode = detectMCCFromHint(categoryHint)
                        categories.append(CashbackCategory(mccCode: mccCode, cashbackPercent: percent))
                    }
                }
            }
        }

        return categories
    }

    private func detectMCCFromHint(_ hint: String) -> String {
        if hint.contains("продукт") || hint.contains("супермарк") {
            return "5411" // Groceries
        } else if hint.contains("кафе") || hint.contains("рестор") {
            return "5814" // Restaurants
        } else if hint.contains("азс") || hint.contains("бензин") {
            return "5542" // Gas stations
        } else if hint.contains("такси") {
            return "4121" // Taxi
        } else if hint.contains("аптек") {
            return "5912" // Pharmacies
        } else if hint.contains("одежд") || hint.contains("обув") {
            return "5651" // Clothing
        }

        return "0000" // Unknown
    }
}
```

### On-Device OCR (Android)

```kotlin
// android/app/src/main/kotlin/com/kartoved/services/OCRService.kt
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class OCRService {
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    fun recognizeText(image: InputImage, callback: (Result<List<String>>) -> Unit) {
        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                val lines = visionText.textBlocks.flatMap { block ->
                    block.lines.map { line -> line.text }
                }
                callback(Result.success(lines))
            }
            .addOnFailureListener { e ->
                callback(Result.failure(e))
            }
    }

    fun extractCashbackCategories(lines: List<String>): List<CashbackCategory> {
        val categories = mutableListOf<CashbackCategory>()
        val pattern = Regex("""([\d.,]+)\s*%\s*.*?(продукт|кафе|рестора|азс|такси|аптек|одежд)""", RegexOption.IGNORE_CASE)

        for (line in lines) {
            val match = pattern.find(line)
            if (match != null) {
                val percentString = match.groupValues[1].replace(",", ".")
                val categoryHint = match.groupValues[2].lowercase()
                val percent = percentString.toDoubleOrNull()

                if (percent != null) {
                    val mccCode = detectMCCFromHint(categoryHint)
                    categories.add(CashbackCategory(mccCode, percent))
                }
            }
        }

        return categories
    }

    private fun detectMCCFromHint(hint: String): String {
        return when {
            hint.contains("продукт") || hint.contains("супермарк") -> "5411"
            hint.contains("кафе") || hint.contains("рестор") -> "5814"
            hint.contains("азс") || hint.contains("бензин") -> "5542"
            hint.contains("такси") -> "4121"
            hint.contains("аптек") -> "5912"
            hint.contains("одежд") || hint.contains("обув") -> "5651"
            else -> "0000"
        }
    }
}
```

### Cloud Fallback (AWS Textract)

```typescript
// backend/src/services/ocr.service.ts
import AWS from 'aws-sdk';

const textract = new AWS.Textract({
    region: process.env.AWS_REGION,
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
});

export async function processWithTextract(imageBuffer: Buffer): Promise<string[]> {
    const params = {
        Document: { Bytes: imageBuffer },
        FeatureTypes: ['FORMS', 'TABLES']
    };

    const result = await textract.analyzeDocument(params).promise();
    const lines: string[] = [];

    if (result.Blocks) {
        for (const block of result.Blocks) {
            if (block.BlockType === 'LINE' && block.Text) {
                lines.push(block.Text);
            }
        }
    }

    return lines;
}
```

### MCC Classification from Merchant Name (AI)

```typescript
// Use Yandex GPT API for Russian merchant names
import axios from 'axios';

const YANDEX_GPT_API_KEY = process.env.YANDEX_GPT_API_KEY;

async function classifyMerchantName(merchantName: string): Promise<string> {
    const prompt = `Определи MCC код для магазина "${merchantName}".

MCC коды:
5411 - Продукты (Пятёрочка, Магнит, Перекрёсток)
5814 - Кафе и рестораны (Макдональдс, Шоколадница)
5542 - АЗС (Лукойл, Газпром)
4121 - Такси (Яндекс.Такси)
5912 - Аптеки (Ригла, Озерки)

Ответь только кодом (4 цифры).`;

    const response = await axios.post('https://llm.api.cloud.yandex.net/foundationModels/v1/completion', {
        modelUri: 'gpt://b1g.../yandexgpt-lite/latest',
        completionOptions: {
            stream: false,
            temperature: 0.1,
            maxTokens: 10
        },
        messages: [
            { role: 'user', text: prompt }
        ]
    }, {
        headers: {
            'Authorization': `Api-Key ${YANDEX_GPT_API_KEY}`,
            'Content-Type': 'application/json'
        }
    });

    const mccCode = response.data.result.alternatives[0].message.text.trim();
    return mccCode.match(/\d{4}/) ? mccCode : '0000';
}
```

---

**Last Updated:** 2026-02-07
