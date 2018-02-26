package com.tp_link.eap.util.system;

import com.tp_link.eap.configuration.Configuration;
import com.tp_link.eap.configuration.ConfigurationFactory;
import com.tp_link.eap.util.common.StringUtil;
import java.awt.Desktop;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.BindException;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.regex.Pattern;
import org.slf4j.Logger;

public class SystemUtil
{
  private static final String NETSTAT_TYPE_LISTENING = "LISTENING";
  
  private static final String WINDOWS_COMMAND_NETSTAT = "netstat -ano";
  private static final String WINDOWS_COMMAND_TASKLIST = "tasklist";
  private static final String WINDOWS_COMMAND_TASKLIST_PID_EQ = "tasklist /FI \"PID eq ";
  private static final String WINDOWS_COMMAND_TASKLIST_KILL = "taskkill /F /PID ";
  private static final String WINDOWS_COMMAND_TASKLIST_KILL_IM = "taskkill /F /IM ";
  
 
  private static final String LINUX_COMMAND_NETSTAT = "netstat -pltu";
  private static final String LINUX_COMMAND_PORT_PID = "netstat -tlnp|grep %s|awk '{print $7}'|awk -F '/' '{print $1}'";
  
  private static final String BSD_COMMAND_NETSTAT = "sockstat -cl";
  private static final String BSD_COMMAND_PORT_PID = "sockstat -cl|grep %s|awk '{print $7}'|awk -F '/' '{print $1}'";
  
  private static final String COMMAND_PS = "ps -e";
  private static final String COMMAND_PS_PID_EQ = "ps -e | grep ";
  private static final String COMMAND_PS_KILL = "kill -9 ";
  private static final String COMMAND_PS_KILL_IM = "";
  private static final Logger logger = org.slf4j.LoggerFactory.getLogger(SystemUtil.class);
  

  private static List<InterfaceAddress> NETWORK_INTERFACES_LIST = new ArrayList();
  private static final String LOCAL_HOST_IP = "127.0.0.1";
  private static final String IP_PATTERN = "((2[0-4]\\d|25[0-5]|[01]?\\d\\d?)\\.){3}(2[0-4]\\d|25[0-5]|[01]?\\d\\d?)";
  private static final Pattern PATTERN = Pattern.compile("((2[0-4]\\d|25[0-5]|[01]?\\d\\d?)\\.){3}(2[0-4]\\d|25[0-5]|[01]?\\d\\d?)");
  
  private static final ScheduledExecutorService scheduledExecutor = java.util.concurrent.Executors.newSingleThreadScheduledExecutor();
  
  private static ReadWriteLock _lock = new java.util.concurrent.locks.ReentrantReadWriteLock();
  
  private static volatile boolean refresh = true;
  private static final int GC_INTERVAL = 1000;
  
  static {
    getAllInterfaceAddress();
    scheduledExecutor.scheduleAtFixedRate(new ScanNetworkInterfaces(), 10L, 10L, java.util.concurrent.TimeUnit.SECONDS);
  }
  
  public static String getCurrentSystemProcessID()
  {
    String processName = java.lang.management.ManagementFactory.getRuntimeMXBean().getName();
    return processName.split("@")[0];
  }
  
  
  public static boolean isWindowsOS()
  {
    String osName = System.getProperty("os.name");
    if (osName.toLowerCase().indexOf("windows") > -1)
		return true;
    return false;
  }
  
  public static boolean isLinuxOS()
  {
    String osName = System.getProperty("os.name");
    if (osName.toLowerCase().indexOf("linux") > -1)
		return true;
    return false;
  }
  
  public static boolean isBSDOS()
  {
	
    String osName = System.getProperty("os.name");
	if (osName.toLowerCase().indexOf("bsd") > -1)
		return true;
    return false;
  }
  
    public static boolean checkProcess(String name)
    throws IOException
  {
    if (StringUtil.isNull(name)) {
      return false;
    }
    BufferedReader reader = new BufferedReader(new InputStreamReader(execute(getPidEqTaskListCommand(name)).getInputStream()));
    

    String line = null;
    while ((line = reader.readLine()) != null) {
      if (line.indexOf(name) > -1) {
        reader.close();
        return true;
      }
    }
    reader.close();
    return false;
  }
  
  private static String getPidEqTaskListCommand(String pid) {
    if (isWindowsOS()) {
      return "tasklist /FI \"PID eq " + pid + "\"";
    }
    if (isLinuxOS() || isBSDOS())
    {
      return "ps -e";
    }
    return null;
  }
  

  public static String getPidByPort(String port)
    throws IOException
  {
    String[] splits;
    
    Iterator i$;
    String info;
    if (isWindowsOS()) {
      List<String> netstatInfos = getNetstatInfosByPort(port);
      splits = null;
      if (!org.springframework.util.CollectionUtils.isEmpty(netstatInfos))
        for (i$ = netstatInfos.iterator(); i$.hasNext();) { info = (String)i$.next();
          if (info.indexOf("0.0.0.0:0") > -1) {
            splits = info.split(" ");
            return splits[(splits.length - 1)];
          }
        }
    }
    
    if (isLinuxOS() || isBSDOS()) {
      BufferedReader reader = null;
      String command;
	  command = (isLinuxOS())
			? String.format(LINUX_COMMAND_PORT_PID, new Object[] { port })
			: String.format(BSD_COMMAND_PORT_PID, new Object[] { port });
      try {
        reader = new BufferedReader(new InputStreamReader(execute(command).getInputStream()));
        
        String line = null;
        while ((line = reader.readLine()) != null) {
          if (line.indexOf(":" + port + " ") > -1) {
            return line;
          }
        }
        
      }
      catch (IOException localIOException2) {}finally
      {
        if (null != reader) {
          try {
            reader.close();
          }
          catch (IOException localIOException4) {}
        }
      }
    }
			  return null;
  }
  
  private static List<String> getNetstatInfosByPort(String port)
  {
    List<String> netstatInfos = new ArrayList();
    BufferedReader reader = null;
    try {
      if (isLinuxOS()) {
        reader = new BufferedReader(new InputStreamReader(execute(LINUX_COMMAND_NETSTAT).getInputStream()));
      } else if (isBSDOS()) {
		reader = new BufferedReader(new InputStreamReader(execute(BSD_COMMAND_NETSTAT).getInputStream()));
	  } else {
        reader = new BufferedReader(new InputStreamReader(execute(WINDOWS_COMMAND_NETSTAT).getInputStream()));
      }
      
      String line = null;
      while ((line = reader.readLine()) != null) {
        if (line.indexOf(":" + port + " ") > -1) {
          netstatInfos.add(line);
        }
      }
    }
    catch (IOException localIOException1) {}finally
    {
      if (null != reader) {
        try {
          reader.close();
        }
        catch (IOException localIOException3) {}
      }
    }
	return netstatInfos;
  }
  
  private static boolean portOccupied(String port, String type) throws IOException
  {
    try {
      if ((type == null) || (type.equalsIgnoreCase("udp"))) {
        DatagramSocket socket = new DatagramSocket(Integer.valueOf(port).intValue());
        socket.close();
      }
      if ((type == null) || (type.equalsIgnoreCase("tcp"))) {
        ServerSocket tcp = new ServerSocket(Integer.valueOf(port).intValue());
        tcp.close();
      }
    } catch (BindException e) {
      logger.debug("get bind exception for port :" + port);
      return true;
    }
    return false;
  }
  
  private static boolean mongodbPortOccupiedCheck(String port) {
    return !org.springframework.util.CollectionUtils.isEmpty(getNetstatInfosByPort(port));
  }
  
  public static boolean portOccupied(String port)
    throws IOException
  {
    if ((port != null) && (port.equals(getMongodbPort()))) {
      return mongodbPortOccupiedCheck(port);
    }
    return portOccupied(port, null);
  }
  
  private static String getMongodbPort() {
    Configuration conf = ConfigurationFactory.loadConfiguration("mongodb.properties");
    
    return conf.getProperty("eap.mongod.port");
  }
  

  public static void shutDownMongoDb(String port)
    throws IOException
  {
    String pid = getPidByPort(port);
    logger.debug("mongodb pid is :" + pid);
    if (!StringUtil.isNull(pid)) {
      killProcessByProcessID(pid);
    }
  }
    public static Process execute(String command)
    throws IOException
  {
    return Runtime.getRuntime().exec(command);
  }
  
  public static Process executeBySh(String command) throws IOException {
    String[] cmd = { "sh", "-c", command };
    System.err.println(command);
    return Runtime.getRuntime().exec(cmd);
  }
  

  public static void killProcessByProcessID(String pid)
    throws IOException
  {
    if (!StringUtil.isNull(pid)) {
      if (isWindowsOS()) {
        execute("taskkill /F /PID " + pid);
      }
      if (isLinuxOS() || isBSDOS()) {
        execute("kill -9 " + pid);
      }
    }
  }
  

  public static void killProcessByImageName(String imageName)
    throws IOException
  {
    if (isWindowsOS()) {
      execute("taskkill /F /IM " + imageName);
    }
    if (isLinuxOS() || isBSDOS()) {
      execute("" + imageName);
    }
  }
    public static boolean openUrl(String ip, Integer port)
  {
    String url = "http://" + ip + ":" + port;
    String osName = System.getProperty("os.name");
    try {
      if (!osName.startsWith("Mac OS"))
      {

        if (osName.startsWith("Windows"))
        {
          Desktop.getDesktop().browse(new java.net.URI(url));
        } else
          Desktop.getDesktop().browse(new java.net.URI(url));
      }
      return true;
    } catch (Exception e) {
      logger.warn("open url exception : ", e); }
    return false;
  }
  
  public static List<InterfaceAddress> getAllInterfaceAddress()
  {
    _lock.readLock().lock();
    if (refresh) {
      logger.debug("RESET NETWORK LIST");
      refresh = false;
      List<InterfaceAddress> list = new ArrayList();
      try {
        Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
        while (interfaces.hasMoreElements()) {
          NetworkInterface ni = (NetworkInterface)interfaces.nextElement();
          List<InterfaceAddress> addresses = ni.getInterfaceAddresses();
          for (InterfaceAddress addr : addresses) {
            String ip = addr.getAddress().getHostAddress();
            if (ip != null) {
              java.util.regex.Matcher matcher = PATTERN.matcher(ip);
              if ((matcher.find()) && (!ip.equals("127.0.0.1"))) {
                list.add(addr);
              }
            }
          }
        }
      }
      catch (java.net.SocketException e) {
        logger.warn("get local net interface address exception : ", e);
      }
      sortAddressBySubnetMask(list);
      NETWORK_INTERFACES_LIST = list;
      _lock.readLock().unlock();
      return list;
    }
    _lock.readLock().unlock();
    return NETWORK_INTERFACES_LIST;
  }
  
  private static void sortAddressBySubnetMask(List<InterfaceAddress> interfaceAddresses)
  {
    java.util.Collections.sort(interfaceAddresses, new java.util.Comparator<InterfaceAddress>()
    {
      public int compare(InterfaceAddress o1, InterfaceAddress o2) {
        if (o1.getNetworkPrefixLength() > o2.getNetworkPrefixLength()) {
          return -1;
        }
        return 1;
      }
    });
  }
  
  public static List<String> getAllLocalIps()
  {
    List<String> list = new ArrayList();
    List<InterfaceAddress> interfaceAddresses = getAllInterfaceAddress();
    for (InterfaceAddress ifa : interfaceAddresses) {
      list.add(ifa.getAddress().getHostAddress());
    }
    return list;
  }
  

  public static void addUser(String command, String username, String password)
    throws IOException
  {
    BufferedWriter writer = null;
    Process process = execute(command);
    try {
      writer = new BufferedWriter(new java.io.OutputStreamWriter(process.getOutputStream()));
      writer.write("db.addUser('" + username + "','" + password + "'); \r\n");
      writer.write("exit; \r\n");
      writer.flush();
    } finally {
      if (null != writer) {
        writer.close();
      }
    }
  }
  

  static class ScanNetworkInterfaces
    implements Runnable
  {
    public void run()
    {
    }
  }
  
  public static void addFireWallRule() {
    if (isWindowsOS()) {
      Configuration conf = ConfigurationFactory.loadConfiguration("eap.properties");
      
      String addFireWallCommand = conf.getProperty("eap.add.firewall.command");
      try {
        logger.debug("add failwall command:" + addFireWallCommand);
        execute(addFireWallCommand);
      } catch (IOException e) {
        logger.debug("fail to add firewall rule", e);
      }
    }
  }
  
  public static void deleteFireWallRule() {
    if (isWindowsOS()) {
      Configuration conf = ConfigurationFactory.loadConfiguration("eap.properties");
      
      String deleteFireWallCommand = conf.getProperty("eap.delete.firewall.command");
      try
      {
        logger.debug("delete failwall command:" + deleteFireWallCommand);
        execute(deleteFireWallCommand);
      } catch (IOException e) {
        logger.debug("fail to delete all related firewall rule", e);
      }
    }
  }
  
  public static void addDiscoverFireWallRule()
  {
    if (isWindowsOS()) {
      Configuration conf = ConfigurationFactory.loadConfiguration("eap.properties");
      
      String addFireWallCommand = conf.getProperty("discover.add.firewall.command");
      try {
        logger.debug("add firewall command:" + addFireWallCommand);
        execute(addFireWallCommand);
      } catch (IOException e) {
        logger.debug("fail to add firewall rule", e);
      }
    }
  }
  
  public static void deleteDiscoverFireWallRule() {
    if (isWindowsOS()) {
      Configuration conf = ConfigurationFactory.loadConfiguration("eap.properties");
      
      String deleteFireWallCommand = conf.getProperty("discover.delete.firewall.command");
      try
      {
        logger.debug("delete firewall command:" + deleteFireWallCommand);
        execute(deleteFireWallCommand);
      } catch (IOException e) {
        logger.debug("fail to delete all related firewall rule", e);
      }
    }
  }
  
  public static void systemGc()
  {
    Thread fullGcThread = new Thread(new Runnable() {
      int triggerTimes = 5;
      
      public void run() { while (this.triggerTimes-- > 0) {
          System.gc();
          try {
            Thread.currentThread();Thread.sleep(1000L);
          } catch (InterruptedException e) {
            e.printStackTrace();
          }
          
        }
        
      }
    });
    fullGcThread.start();
  }
}
