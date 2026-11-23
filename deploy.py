import os
import shutil
import zipfile
import paramiko
import sys
import hashlib

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

SERVER_HOST = 'hersolan.pro'
SSH_PORT = 22
SSH_USER = 'hersolot'
SSH_PASS = 'v:89]yYLi:7t7O0E)0*'
TARGET_SUBDOMAIN = 'app'
TARGET_DIR = f'/home/{SSH_USER}/{TARGET_SUBDOMAIN}.{SERVER_HOST}'
DB_NAME = f'{SSH_USER}_appdb'
DB_USER = 'hersolot_yoni'
DB_PASS = 'KAS@wifi1'

def package_project(zip_filename='project.zip'):
    print(f'Packaging project into {zip_filename}...')
    if os.path.exists(zip_filename):
        os.remove(zip_filename)
        
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as z:
        # 1. Add laravel files (excluding vendor and storage/logs/framework caches)
        for root, dirs, files in os.walk('laravel'):
            # Ignore vendor, .git, tests, storage, .phpunit.cache
            if 'vendor' in root.split(os.sep) or '.git' in root.split(os.sep) or 'storage' in root.split(os.sep):
                continue
            for f in files:
                # Local .env files are never shipped: the server keeps its own .env (written below).
                # Shipping laravel/.env replaced it for a few seconds per deploy (DB user root → errors).
                if f.endswith('.log') or f == '.phpunit.result.cache' or f.startswith('.env'):
                    continue
                file_path = os.path.join(root, f)
                rel_path = os.path.relpath(file_path, 'laravel')
                z.write(file_path, rel_path)
                
        # 2. Add flutter web build to public/
        web_dir = 'mobile/mobile/build/web'
        if os.path.exists(web_dir):
            print('Adding Flutter web build into public/...')
            for root, dirs, files in os.walk(web_dir):
                for f in files:
                    file_path = os.path.join(root, f)
                    rel_path = os.path.relpath(file_path, web_dir)
                    target_zip_path = os.path.join('public', rel_path).replace('\\', '/')
                    z.write(file_path, target_zip_path)
                    
        # 3. Add root .htaccess to forward requests to public/
        root_htaccess = '''<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/public/
    RewriteRule ^(.*)$ public/$1 [L,QSA]
</IfModule>

<Files .env>
    Order allow,deny
    Deny from all
</Files>
'''
        z.writestr('.htaccess', root_htaccess)
        
        # 4. Add root index.php as fallback
        root_index = '''<?php
// Forward to public/index.php
require __DIR__ . '/public/index.php';
'''
        z.writestr('index.php', root_index)

    print(f'Project packaged successfully ({os.path.getsize(zip_filename)} bytes).')

def deploy():
    package_project('project.zip')
    
    print(f'Connecting to {SERVER_HOST} via SSH...')
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(SERVER_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASS, timeout=60, banner_timeout=60, auth_timeout=60)
    
    # Pre-deployment database backup
    print('Creating pre-deployment database backup on server...')
    backup_cmd = (
        f'mkdir -p /home/{SSH_USER}/backups && '
        f'BACKUP_FILE="/home/{SSH_USER}/backups/{DB_NAME}_predeploy_$(date +%Y%m%d_%H%M%S).sql" && '
        f'mysqldump -u {DB_USER} -p"{DB_PASS}" {DB_NAME} > "$BACKUP_FILE" && '
        f'ls -lh "$BACKUP_FILE"'
    )
    stdin, stdout, stderr = ssh.exec_command(backup_cmd)
    backup_out = stdout.read().decode('utf-8', errors='replace').strip()
    backup_err = stderr.read().decode('utf-8', errors='replace').strip()
    if backup_err and 'Deprecated program name' not in backup_err:
        print('Database backup notice/warning:', backup_err)
    print('Database backup result:', backup_out)

    # Ensure vendor dependencies exist without duplicating
    print('Checking vendor dependencies on server...')
    ssh.exec_command(f'rm -rf {TARGET_DIR}/vendor/vendor')
    stdin, stdout, stderr = ssh.exec_command(f'[ -d {TARGET_DIR}/vendor ] || cp -a /home/{SSH_USER}/mhs.{SERVER_HOST}/vendor {TARGET_DIR}/vendor')
    stdout.channel.recv_exit_status()
    
    # Upload project.zip via SFTP
    print(f'Uploading project.zip ({os.path.getsize("project.zip"):,} bytes) to {TARGET_DIR}/...')
    sftp = ssh.open_sftp()
    last_pct = [0]
    def zip_progress(transferred, total):
        pct = int((transferred / total) * 100)
        if pct >= last_pct[0] + 10 or pct == 100:
            print(f'  project.zip upload progress: {pct}% ({transferred:,} / {total:,} bytes)')
            last_pct[0] = pct
    sftp.put('project.zip', f'{TARGET_DIR}/project.zip', callback=zip_progress)
    sftp.close()
    
    # Extract project.zip remotely
    print('Extracting project.zip on server...')
    stdin, stdout, stderr = ssh.exec_command(f'cd {TARGET_DIR} && unzip -o project.zip && rm -f project.zip')
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    print('Extract done.')
    if err:
        print('Extract stderr:', err[:300])
        
    # Write production .env remotely
    print('Setting up production .env...')
    prod_env = f'''APP_NAME="Meserete Hiwot"
APP_ENV=production
APP_KEY=base64:Q+LSM0tVbukjw3CZwCaCkog87gYztiJXaNUJ0pyL3FY=
DATA_ENCRYPTION=true
DATA_ENCRYPTION_KEY=
DATA_ENCRYPTION_OLD_KEYS=
APP_DEBUG=false
APP_URL=https://app.{SERVER_HOST}
PUBLIC_BASE_URL=https://app.{SERVER_HOST}

APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US

APP_MAINTENANCE_DRIVER=file

PHP_CLI_SERVER_WORKERS=4
BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE={DB_NAME}
DB_USERNAME={DB_USER}
DB_PASSWORD={DB_PASS}

SESSION_DRIVER=file
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
CACHE_STORE=file

CACHE_EDU_DASHBOARD=true
EDU_STRICT_CURRICULUM_GATE=true
EDU_UNIFIED_QUIZ_BUILDER=true

MEMCACHED_HOST=127.0.0.1
REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_SCHEME=null
MAIL_HOST=127.0.0.1
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="Meserete Hiwot"

# --- Timezone & CORS ---
APP_TIMEZONE=Africa/Addis_Ababa
CORS_ORIGINS=http://localhost:8000,http://localhost:3000,http://localhost:4000,http://localhost:5000,https://app.{SERVER_HOST},http://app.{SERVER_HOST},https://mhs.{SERVER_HOST},https://mh.{SERVER_HOST},https://api.mh.{SERVER_HOST}
TRUST_PROXY=0

# --- JWT ---
JWT_SECRET=397a90ddf325b2b05d7e9f5a9cd67d38f927b987678f404ca6a9972b13388878bdf974a1db286b460587777e93e2103a
JWT_REFRESH_SECRET=97e6a7501e963f6d5b156528617d848dd4d65d3a7fda15a77ef157bfb1d70bf77eea9516157b3b3aceab8c8f5c576b0a
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL_DAYS=0
JWT_ISSUER=mezmur-zelideta-api
JWT_AUDIENCE=mezmur-zelideta-app

# --- Internal System Authority ---
SYSTEM_ENCRYPTION_KEY=b4128795c5282aba17e6369fb8add84c4fd9a52161296e5d6c3dc530b39f9a48
SYSTEM_ACCESS_TTL=10m
SYSTEM_REFRESH_TTL_HOURS=0
SYSTEM_ALLOWED_IPS=

# --- Telegram Bot ---
TELEGRAM_BOT_TOKEN=8968084381:AAHYqefEFupGnIjuOGKWslfZayHUogHORmc
TELEGRAM_BOT_USERNAME=Mezmure_Zelideta_bot
TELEGRAM_WEBHOOK_SECRET=www
'''
    sftp = ssh.open_sftp()
    with sftp.file(f'{TARGET_DIR}/.env', 'w') as f:
        f.write(prod_env)
    sftp.close()
    
    # Fix directory permissions & storage symlink
    print('Ensuring directory permissions and storage symlink...')
    ssh.exec_command(f'mkdir -p {TARGET_DIR}/storage/framework/views {TARGET_DIR}/storage/framework/cache {TARGET_DIR}/storage/framework/sessions {TARGET_DIR}/storage/logs {TARGET_DIR}/bootstrap/cache {TARGET_DIR}/storage/mz/public {TARGET_DIR}/resources/views')
    ssh.exec_command(f'chmod -R 775 {TARGET_DIR}/storage {TARGET_DIR}/bootstrap/cache')
    ssh.exec_command(f'chmod -R 777 {TARGET_DIR}/storage/mz/public')
    ssh.exec_command(f'[ -L {TARGET_DIR}/public/files ] || ln -s ../storage/mz/public {TARGET_DIR}/public/files')
    
    # Upload APK if exists and register release in database
    apk_path = 'mobile/mobile/build/app/outputs/flutter-apk/app-release.apk'
    if os.path.exists(apk_path):
        apk_size = os.path.getsize(apk_path)
        print(f'Uploading {apk_path} ({apk_size:,} bytes) to public/app-release.apk...')
        
        # Calculate SHA256
        sha256_hash = hashlib.sha256()
        with open(apk_path, 'rb') as f:
            for byte_block in iter(lambda: f.read(65536), b""):
                sha256_hash.update(byte_block)
        apk_sha256 = sha256_hash.hexdigest()
        
        # Check if APK is already on server with matching size
        remote_apk = f'{TARGET_DIR}/public/app-release.apk'
        stdin, stdout, stderr = ssh.exec_command(f'[ -f {remote_apk} ] && stat -c %s {remote_apk} || echo 0')
        remote_size_str = stdout.read().decode('utf-8', errors='replace').strip()
        remote_size = int(remote_size_str) if remote_size_str.isdigit() else 0

        if remote_size == apk_size:
            print(f'Remote APK already matches local size ({apk_size:,} bytes). Skipping SFTP upload.')
        else:
            print(f'Uploading {apk_path} ({apk_size:,} bytes) to public/app-release.apk...')
            sftp = ssh.open_sftp()
            last_pct = [0]
            def progress_callback(transferred, total):
                pct = int((transferred / total) * 100)
                if pct >= last_pct[0] + 10 or pct == 100:
                    print(f'  APK upload progress: {pct}% ({transferred:,} / {total:,} bytes)')
                    last_pct[0] = pct
            sftp.put(apk_path, remote_apk, callback=progress_callback)
            sftp.chmod(remote_apk, 0o644)
            sftp.close()

        # Copy to private/releases on server locally (instant, no extra network overhead)
        print('Ensuring private releases directory exists...')
        ssh.exec_command(f'mkdir -p {TARGET_DIR}/storage/mz/private/releases')
        remote_release_path = 'private/releases/release-1.5.3-38.apk'
        print(f'Copying APK to {TARGET_DIR}/storage/mz/{remote_release_path} on server...')
        stdin, stdout, stderr = ssh.exec_command(
            f'cp {remote_apk} {TARGET_DIR}/storage/mz/{remote_release_path} && chmod 644 {TARGET_DIR}/storage/mz/{remote_release_path}'
        )
        stdout.channel.recv_exit_status()
        print('APK setup complete.')

        # Register in app_releases table (NOT forced update: is_mandatory=0, min_supported_code=0)
        print('Registering release 1.5.3+38 in app_releases database table (non-forced update)...')
        notes = "Release 1.5.3+38: Full Master Prompt UI/UX release - Universal Quiz Builder, Curriculum Explorer, Admin Grade Explorer, fast calendar attendance actions, dedicated physical/digital library books, and attendance dashboard fixes."
        sql = (
            f"UPDATE app_releases SET is_mandatory=0, min_supported_code=0 WHERE platform='android'; "
            f"INSERT INTO app_releases (platform, version_name, version_code, file_path, file_size, sha256, release_notes, min_supported_code, is_mandatory, is_published, download_count, created_at) "
            f"VALUES ('android', '1.5.3', 38, '{remote_release_path}', {apk_size}, '{apk_sha256}', '{notes}', 0, 0, 1, 0, NOW()) "
            f"ON DUPLICATE KEY UPDATE version_name='1.5.3', file_path='{remote_release_path}', file_size={apk_size}, sha256='{apk_sha256}', release_notes='{notes}', min_supported_code=0, is_mandatory=0, is_published=1;"
        )
        cmd = f"mysql -u {DB_USER} -p'{DB_PASS}' {DB_NAME} -e \"{sql}\""
        stdin, stdout, stderr = ssh.exec_command(cmd)
        stdout.read()
        err = stderr.read().decode('utf-8', errors='replace')
        if err and 'Deprecated program name' not in err:
            print('Release DB registration warning/error:', err)
        else:
            print('Release 1.5.3+38 registered successfully in database (force_update disabled).')
    
    # Run migrations and seeders
    print('Running migrations, cache clears and GuidanceSeeder on server...')
    artisan_cmd = (
        f'cd {TARGET_DIR} && '
        'php artisan config:clear && '
        'php artisan cache:clear && '
        'php artisan route:clear && '
        'php artisan view:clear && '
        'php artisan optimize:clear && '
        'php artisan migrate --force && '
        'php artisan db:seed --class=GuidanceSeeder --force && '
        'php artisan mz:telegram-webhook && '
        'php artisan config:cache && '
        'php artisan route:cache && '
        'php artisan view:cache'
    )
    stdin, stdout, stderr = ssh.exec_command(artisan_cmd)
    print('Artisan output:\n', stdout.read().decode('utf-8', errors='replace'))
    err = stderr.read().decode('utf-8', errors='replace')
    if err:
        print('Artisan stderr:\n', err)
        
    # Test HTTP endpoints
    print('Testing HTTP responses...')
    stdin, stdout, stderr = ssh.exec_command(f'curl -sI -k https://app.{SERVER_HOST}/health')
    print('CURL /health:\n', stdout.read().decode('utf-8', errors='replace'))
    
    stdin, stdout, stderr = ssh.exec_command(f'curl -sI -k https://app.{SERVER_HOST}/')
    print('CURL / (root):\n', stdout.read().decode('utf-8', errors='replace'))

    for vcode in [0, 26, 33, 37]:
        stdin, stdout, stderr = ssh.exec_command(f'curl -s -k "https://app.{SERVER_HOST}/api/v1/app/version?version_code={vcode}"')
        print(f'CURL /api/v1/app/version (v={vcode}):\n', stdout.read().decode('utf-8', errors='replace'))

    stdin, stdout, stderr = ssh.exec_command(f'curl -s -k https://app.{SERVER_HOST}/api/v1/sinksar/today')
    print('CURL /api/v1/sinksar/today:\n', stdout.read().decode('utf-8', errors='replace')[:400])

    stdin, stdout, stderr = ssh.exec_command(f'curl -sI -k https://app.{SERVER_HOST}/public/app-release.apk')
    print('CURL /public/app-release.apk:\n', stdout.read().decode('utf-8', errors='replace'))
    
    ssh.close()
    print('Deployment completed successfully!')

if __name__ == '__main__':
    deploy()
