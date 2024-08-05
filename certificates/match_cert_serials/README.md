# Match cert serials

This is a simple yet effective script designed to match serial numbers of certificates within a container against a set of known certificate serial numbers.

## Purpose

The primary puspose of this script is to identify missing or incorrect CA certifiicates when troubleshooting TLS authentication failures with external services in container orchestration platforms such as OKD, OpenShift, or Kubernetes.

## How It Works

The script performs the following steps:

1. **Iterate Through Certificates:** It scans through all the certificates in a specified directory (e.g., `/etc/ssl/certs`).
2. **Extract Serial Numbers:** For each certificate, it extracts the serial number and formats it for comparison.
3. **Match Against Known Serials:** The script compares the extracted serial numbers against a predefined list of known serial numbers.
4. **Output Results:** 
   - If a match is found, the script outputs a "MATCH" message in green.
   - If no match is found, it outputs a "NO MATCH" message in red.

## Usage

### Running the Script

You can run the script directly from your terminal without saving it to a file. Here’s how you can do it:

```bash
bash -c '
verbosity=1
verbose() {
  if [ "$verbosity" -ge "$1" ]; then
    echo -e "$2"
  fi
}

for cert in $(ls | grep "pem"); do
  serial=$(openssl x509 -in "$cert" -noout -serial | cut -d'=' -f2 | tr "[:lower:]" "[:upper:]")
  match_found=false
  for known_serial in "083BE056904246B1A1756AC95991C74A" "02742EAA17CA8E21C717BB1FFCFD0CA0" "0B9E93A35CC32981279A82EFD7C62338"; do
    verbose 2 "Matching $cert with serial $serial against known serial $known_serial..."
    if [[ "$serial" == "$known_serial" ]]; then
      echo -e "Matching $cert with serial $serial: \e[32mMATCH\e[0m"
      match_found=true
      break
    fi
  done
  if [ "$match_found" = false ]; then
    echo -e "Matching $cert with serial $serial: \e[31mNO MATCH\e[0m"
  fi
done
'
```

### Adjusting Verbosity

The script includes a verbosity function that controls the level of detail in the output:

- **Normal Verbosity (Default):** Displays only `MATCH` or `NO MATCH` results.
- **Increased Verbosity:** To see detailed matching information, you can adjust the verbosity level by changing `verbosity=1` to `verbosity=2` in the script.

### Example Output

- **Match Found:**
  ```
  Matching /etc/ssl/certs/mycert.pem with serial 083BE056904246B1A1756AC95991C74A: MATCH
  ```

- **No Match Found:**
  ```
  Matching /etc/ssl/certs/othercert.pem with serial ABCD1234EF567890: NO MATCH
  ```

## Use Cases

- **TLS Authentication Debugging:** Quickly identify whether the necessary CA certificates are present in your container’s trust store.
- **Security Audits:** Ensure that the certificates in your environment are correctly configured and recognized.

## Prerequisites

- **OpenSSL:** The script relies on OpenSSL to extract certificate serial numbers.
- **Bash Shell:** This script is intended to be run in a bash shell environment, typically found in Linux containers or environments.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.