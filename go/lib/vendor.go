package external

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"embed"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

//go:embed binaries/*
var embeddedBinaries embed.FS

const embeddedVersion = "v0.0.44"

// GetExternalDir returns the path where external libraries should be installed
// Defaults to ./external relative to the caller's working directory
func GetExternalDir() string {
	if dir := os.Getenv("EXTERNAL_DIR"); dir != "" {
		return dir
	}
	return "external"
}

// EnsureLibraries extracts embedded external libraries if not present
// If a 'FREEZE' file exists in the external directory, checks are skipped
func EnsureLibraries() error {
	externalDir := GetExternalDir()

	// Check if frozen - if so, skip all checks
	if isFrozen(externalDir) {
		return nil
	}

	// Check if we already have this version installed
	installedVersion, err := getInstalledVersion(externalDir)
	if err == nil && installedVersion == embeddedVersion {
		return nil
	}

	if installedVersion != "" && installedVersion != embeddedVersion {
		fmt.Printf("Upgrading external libraries: %s → %s\n", installedVersion, embeddedVersion)
		// Clean out old version
		if err := cleanExternalDir(externalDir); err != nil {
			return fmt.Errorf("failed to clean external directory: %w", err)
		}
	} else if installedVersion == "" {
		fmt.Printf("Installing external libraries: %s\n", embeddedVersion)
	}

	return extractEmbeddedLibraries(externalDir)
}

// extractEmbeddedLibraries extracts all embedded binaries for the current platform
func extractEmbeddedLibraries(externalDir string) error {
	platform := detectPlatform()
	if platform == "" {
		return fmt.Errorf("unsupported platform: %s/%s", runtime.GOOS, runtime.GOARCH)
	}

	// Extract each library
	libraries := []string{"glslang", "spirv-cross", "dxc", "naga"}
	for _, lib := range libraries {
		if err := extractLibrary(lib, platform, externalDir); err != nil {
			return fmt.Errorf("failed to extract %s: %w", lib, err)
		}
	}

	// Write version file to track what's installed
	if err := writeVersionFile(externalDir, embeddedVersion); err != nil {
		fmt.Printf("Warning: Could not write version file: %v\n", err)
	}

	return nil
}

// extractLibrary extracts a single library from embedded binaries
func extractLibrary(library, platform, externalDir string) error {
	// Determine file extension based on library and platform
	ext := ".tar.gz"
	if library == "dxc" && strings.HasPrefix(platform, "windows-") {
		ext = ".zip"
	}

	filename := fmt.Sprintf("%s-%s%s", library, platform, ext)
	embeddedPath := fmt.Sprintf("binaries/%s", filename)

	fmt.Printf("Extracting %s...\n", library)

	// Open embedded file
	file, err := embeddedBinaries.Open(embeddedPath)
	if err != nil {
		return fmt.Errorf("failed to open embedded file %s: %w", embeddedPath, err)
	}
	defer file.Close()

	// Create temporary file for extraction
	tmpFile, err := os.CreateTemp("", fmt.Sprintf("%s-*%s", library, ext))
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)

	// Copy embedded file to temp
	if _, err := io.Copy(tmpFile, file); err != nil {
		tmpFile.Close()
		return fmt.Errorf("failed to write temp file: %w", err)
	}
	tmpFile.Close()

	// Extract based on file type
	if ext == ".tar.gz" {
		if err := extractTarGz(tmpPath, externalDir, library, platform); err != nil {
			return fmt.Errorf("failed to extract tar.gz: %w", err)
		}
	} else {
		if err := extractZip(tmpPath, externalDir, library, platform); err != nil {
			return fmt.Errorf("failed to extract zip: %w", err)
		}
	}

	fmt.Printf("Successfully installed %s\n", library)
	return nil
}

// detectPlatform returns the platform string for binaries
func detectPlatform() string {
	goos := runtime.GOOS
	goarch := runtime.GOARCH

	var os, arch string
	switch goos {
	case "darwin":
		os = "darwin"
	case "linux":
		os = "linux"
	case "windows":
		os = "windows"
	default:
		return ""
	}

	switch goarch {
	case "amd64":
		arch = "amd64"
	case "arm64":
		arch = "arm64"
	default:
		return ""
	}

	return fmt.Sprintf("%s-%s", os, arch)
}

// extractTarGz extracts a .tar.gz file and renames the root directory
func extractTarGz(archivePath, destDir, library, platform string) error {
	file, err := os.Open(archivePath)
	if err != nil {
		return err
	}
	defer file.Close()

	gzr, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer gzr.Close()

	tr := tar.NewReader(gzr)
	platformPrefix := fmt.Sprintf("%s-%s", library, platform)

	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		// Strip platform suffix from path
		name := header.Name
		if strings.HasPrefix(name, platformPrefix+"/") {
			name = library + name[len(platformPrefix):]
		} else if name == platformPrefix {
			name = library
		}

		target := filepath.Join(destDir, name)

		switch header.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0755); err != nil {
				return err
			}
		case tar.TypeReg:
			if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
				return err
			}
			outFile, err := os.OpenFile(target, os.O_CREATE|os.O_RDWR|os.O_TRUNC, os.FileMode(header.Mode))
			if err != nil {
				return err
			}
			if _, err := io.Copy(outFile, tr); err != nil {
				outFile.Close()
				return err
			}
			outFile.Close()
		}
	}

	return nil
}

// extractZip extracts a .zip file and renames the root directory
func extractZip(archivePath, destDir, library, platform string) error {
	r, err := zip.OpenReader(archivePath)
	if err != nil {
		return err
	}
	defer r.Close()

	platformPrefix := fmt.Sprintf("%s-%s", library, platform)

	// Ensure the library root directory exists first
	libRoot := filepath.Join(destDir, library)
	if err := os.MkdirAll(libRoot, 0755); err != nil {
		return fmt.Errorf("failed to create library root directory %s: %w", libRoot, err)
	}

	for _, f := range r.File {
		// Strip platform suffix from path
		// Normalize path separators (ZIP files may use either / or \)
		name := filepath.ToSlash(f.Name)
		if strings.HasPrefix(name, platformPrefix+"/") {
			name = library + name[len(platformPrefix):]
		} else if name == platformPrefix {
			name = library
		}

		target := filepath.Join(destDir, name)

		// Check if entry is a directory (either via FileInfo or trailing separator)
		isDir := f.FileInfo().IsDir() || strings.HasSuffix(name, "/")
		if isDir {
			if err := os.MkdirAll(target, 0755); err != nil {
				return fmt.Errorf("failed to create directory %s: %w", target, err)
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			return err
		}

		outFile, err := os.OpenFile(target, os.O_CREATE|os.O_RDWR|os.O_TRUNC, f.Mode())
		if err != nil {
			return err
		}

		rc, err := f.Open()
		if err != nil {
			outFile.Close()
			return err
		}

		_, err = io.Copy(outFile, rc)
		outFile.Close()
		rc.Close()

		if err != nil {
			return err
		}
	}

	return nil
}

// getInstalledVersion reads the version file to determine what's currently installed
func getInstalledVersion(externalDir string) (string, error) {
	versionFile := filepath.Join(externalDir, ".version")
	data, err := os.ReadFile(versionFile)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

// writeVersionFile writes the current version to a file for future checks
func writeVersionFile(externalDir, version string) error {
	versionFile := filepath.Join(externalDir, ".version")
	return os.WriteFile(versionFile, []byte(version+"\n"), 0644)
}

// cleanExternalDir removes all library directories to prepare for new installation
func cleanExternalDir(externalDir string) error {
	dirsToClean := []string{"glslang", "spirv-cross", "dxc", "naga"}
	for _, dir := range dirsToClean {
		libDir := filepath.Join(externalDir, dir)
		if err := os.RemoveAll(libDir); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("failed to remove %s: %w", libDir, err)
		}
	}
	return nil
}

// isFrozen checks if a 'FREEZE' file exists in the external directory
// If present, automatic updates are disabled
func isFrozen(externalDir string) bool {
	freezeFile := filepath.Join(externalDir, "FREEZE")
	_, err := os.Stat(freezeFile)
	return err == nil
}
