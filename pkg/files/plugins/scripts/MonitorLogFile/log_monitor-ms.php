<?php
require('rcs_function.php');
// get all the variables from the environmental variable
$dir            = getenv('UPTIME_DIR');
$files_regex    = getenv('UPTIME_FILES_REGEX');
$search_regex   = getenv('UPTIME_SEARCH_REGEX');
$ignore_regex   = getenv('UPTIME_IGNORE_REGEX');
$debug_mode     = getenv('UPTIME_DEBUG_MODE');
$agent_hostname = getenv('UPTIME_HOSTNAME');
$agent_port     = getenv('UPTIME_PORT');
$agent_password = getenv('UPTIME_PASSWORD');
$cmdlinevar = '';	// create the one variable for the command line and parse from the main 4 variables
// "contains()" function
// http://www.jonasjohn.de/snippets/php/contains.htm
function contains($str, $content, $ignorecase=true){
    if ($ignorecase){
        $str = strtolower($str);
        $content = strtolower($content);
    }  
    return strpos($str,$content) ? true : false;
}
// determine if the agent is a Windows or other (posix) agent since the Windows agent requires special handling
function is_agent($veroutput, $agenttype) {
	$rv = 0;
	// check if the agent is on Windows or anything else (Posix)
	if (contains($veroutput, $agenttype, true)) {
		$rv = 1;
	}
	if (strlen($veroutput) == 0) {
		$rv = 0;
		print "Error: no lines returned from 'ver'. Is the agent running?";
		exit(1);
	}
	return $rv;
}
// "UPDOTTIME" separates each variable
//print $dir . "\n" . $files_regex . "\n" . $search_regex . "\n" . $ignore_regex . "\n";
$break = 'UPDOTTIME';
$cmdlinevar = base64_encode($dir) . $break .
			  base64_encode($files_regex) . $break .
			  base64_encode($search_regex) . $break .
			  base64_encode($ignore_regex) . $break .
			  $debug_mode;
// depending on the platform (Windows/Others) the command for the remote agent script will be different
$veroutput = agentcmd($agent_hostname, $agent_port, "ver");
if (is_agent($veroutput, "windows")) {
	$cmd = "log-file-monitor";
}
else {
	$agent_password = 'log-file-monitor';
	$cmd = "/opt/uptime-agent/scripts/log-file-monitor.pl";
}
$agent_output = uptime_remote_custom_monitor($agent_hostname, $agent_port, $agent_password, $cmd, $cmdlinevar);
// print $agent_hostname . "\n" . $agent_port . "\n" . $agent_password . "\n" . $cmd . "\n" . $cmdlinevar . "\n";
if (strlen($agent_output) == 0) {
	print "Error: No lines returned from agent.";
	exit(1);
}
if (trim($agent_output) == "ERR") {
	print "Error: Output received: 'ERR'. The agent may not be configured correctly. Check the password?";
	exit(2);
}
print $agent_output;
exit(0);
?>