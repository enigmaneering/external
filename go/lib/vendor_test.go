package external

import (
	"os"
	"path/filepath"
	"testing"
)

func TestEmbeddedBinaries(t *testing.T) {
	// Create temp directory for test
	tmpDir, err := os.MkdirTemp("", "external-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Set external dir to temp
	os.Setenv("EXTERNAL_DIR", tmpDir)
	defer os.Unsetenv("EXTERNAL_DIR")

	// Extract libraries
	if err := EnsureLibraries(); err != nil {
		t.Fatalf("EnsureLibraries failed: %v", err)
	}

	// Verify libraries were extracted
	libraries := []string{"glslang", "spirv-cross", "dxc", "naga"}
	for _, lib := range libraries {
		libDir := filepath.Join(tmpDir, lib)
		if _, err := os.Stat(libDir); os.IsNotExist(err) {
			t.Errorf("Library %s was not extracted", lib)
		}
	}

	// Verify version file
	version, err := getInstalledVersion(tmpDir)
	if err != nil {
		t.Errorf("Failed to read version: %v", err)
	}
	if version != embeddedVersion {
		t.Errorf("Version mismatch: got %s, want %s", version, embeddedVersion)
	}

	// Verify that second call is a no-op
	if err := EnsureLibraries(); err != nil {
		t.Errorf("Second EnsureLibraries failed: %v", err)
	}
}
