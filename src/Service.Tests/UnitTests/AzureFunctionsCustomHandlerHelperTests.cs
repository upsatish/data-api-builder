// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System;
using Azure.DataApiBuilder.Service.Utilities;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Azure.DataApiBuilder.Service.Tests.UnitTests
{
    /// <summary>
    /// Tests for <see cref="AzureFunctionsCustomHandlerHelper"/>, which detects when DAB runs
    /// as an Azure Functions custom handler.
    /// </summary>
    [TestClass]
    [DoNotParallelize]
    public class AzureFunctionsCustomHandlerHelperTests
    {
        private const string PORT_ENVVAR = AzureFunctionsCustomHandlerHelper.FUNCTIONS_CUSTOMHANDLER_PORT_ENVVAR;

        /// <summary>
        /// Validates detection and URL resolution for a range of FUNCTIONS_CUSTOMHANDLER_PORT values.
        /// </summary>
        [DataTestMethod]
        [DataRow("12345", true, "http://localhost:12345", DisplayName = "Valid port")]
        [DataRow(" 8080 ", true, "http://localhost:8080", DisplayName = "Valid port with whitespace")]
        [DataRow(null, false, "", DisplayName = "Unset")]
        [DataRow("", false, "", DisplayName = "Empty")]
        [DataRow("abc", false, "", DisplayName = "Non-numeric")]
        [DataRow("0", false, "", DisplayName = "Zero")]
        [DataRow("-1", false, "", DisplayName = "Negative")]
        [DataRow("70000", false, "", DisplayName = "Out of range")]
        public void TryGetCustomHandlerUrlTest(string envValue, bool expectedDetected, string expectedUrl)
        {
            string original = Environment.GetEnvironmentVariable(PORT_ENVVAR);
            Environment.SetEnvironmentVariable(PORT_ENVVAR, envValue);
            try
            {
                Assert.AreEqual(expectedDetected, AzureFunctionsCustomHandlerHelper.IsRunningAsCustomHandler());
                Assert.AreEqual(expectedDetected, AzureFunctionsCustomHandlerHelper.TryGetCustomHandlerUrl(out string url));
                Assert.AreEqual(expectedUrl, url);
            }
            finally
            {
                Environment.SetEnvironmentVariable(PORT_ENVVAR, original);
            }
        }

        /// <summary>
        /// Validates that the internal port used for health checks follows the custom handler port,
        /// taking precedence over ASPNETCORE_URLS.
        /// </summary>
        [TestMethod]
        public void ResolveInternalPortPrefersCustomHandlerPortTest()
        {
            string originalPort = Environment.GetEnvironmentVariable(PORT_ENVVAR);
            string originalUrls = Environment.GetEnvironmentVariable("ASPNETCORE_URLS");
            Environment.SetEnvironmentVariable(PORT_ENVVAR, "34567");
            Environment.SetEnvironmentVariable("ASPNETCORE_URLS", "http://localhost:5000");
            try
            {
                Assert.AreEqual(34567, PortResolutionHelper.ResolveInternalPort());
            }
            finally
            {
                Environment.SetEnvironmentVariable(PORT_ENVVAR, originalPort);
                Environment.SetEnvironmentVariable("ASPNETCORE_URLS", originalUrls);
            }
        }
    }
}
