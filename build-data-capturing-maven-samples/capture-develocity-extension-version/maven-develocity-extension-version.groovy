/**
 * This Groovy script captures the Develocity Maven extension version as a custom value.
 */

URL url = buildScan.buildScan.class.classLoader.getResource("com.gradle.scan.plugin.internal.meta.buildAgentVersion.txt")
String buildAgentVersion = url.text
buildScan.value("Develocity Maven extension version", buildAgentVersion)
