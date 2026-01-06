import os
import sys
import subprocess
import stat

def main():
    # Resolve the package directory
    package_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Path to the internal bash script
    # Since we symlinked bin/ into the package, it should be here.
    script_path = os.path.join(package_dir, 'bin', 'better-anonymity')
    
    if not os.path.exists(script_path):
        print(f"Error: Could not find script at {script_path}")
        print("Installation might be corrupt.")
        sys.exit(1)
        
    # Ensure it's executable
    st = os.stat(script_path)
    os.chmod(script_path, st.st_mode | stat.S_IEXEC)
    
    # Pass all arguments through to the bash script
    cmd = [script_path] + sys.argv[1:]
    
    try:
        # Run and wait
        sys.exit(subprocess.call(cmd))
    except KeyboardInterrupt:
        sys.exit(130)

if __name__ == "__main__":
    main()
