const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

async function test() {
    const driveLetter = 'd';
    const cmd = `powershell -Command "Get-CimInstance Win32_LogicalDisk -Filter \\"DeviceID='${driveLetter}:'\\" | Select-Object Size, FreeSpace"`;
    console.log(cmd);
    const { stdout } = await execPromise(cmd);
    console.log(stdout);
}
test();
