// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System;

namespace Azure.DataApiBuilder.Service.Utilities
{
    /// <summary>
    /// Detects when Data API builder runs as an Azure Functions custom handler and resolves
    /// the address the Functions host expects the engine to listen on.
    /// </summary>
    /// <remarks>
    /// When an Azure Function App is configured with a custom handler, the Functions host starts the
    /// handler executable and sets the <c>FUNCTIONS_CUSTOMHANDLER_PORT</c> environment variable. The
    /// handler MUST listen for HTTP requests on that port. With <c>enableForwardingHttpRequest</c>
    /// set to true in host.json, the host forwards the original HTTP request (path, query string,
    /// headers and body) to the handler, so DAB's REST, GraphQL, MCP and health endpoints work unchanged.
    /// See https://learn.microsoft.com/azure/azure-functions/functions-custom-handlers
    /// </remarks>
    public static class AzureFunctionsCustomHandlerHelper
    {
        /// <summary>
        /// Environment variable set by the Azure Functions host for custom handlers.
        /// </summary>
        public const string FUNCTIONS_CUSTOMHANDLER_PORT_ENVVAR = "FUNCTIONS_CUSTOMHANDLER_PORT";

        /// <summary>
        /// Attempts to read the port assigned by the Azure Functions host.
        /// </summary>
        /// <param name="port">The assigned port when present and valid.</param>
        /// <returns>True when DAB is running as an Azure Functions custom handler.</returns>
        public static bool TryGetCustomHandlerPort(out int port)
        {
            string? value = Environment.GetEnvironmentVariable(FUNCTIONS_CUSTOMHANDLER_PORT_ENVVAR);
            if (int.TryParse(value?.Trim(), out port) && port > 0 && port <= 65535)
            {
                return true;
            }

            port = 0;
            return false;
        }

        /// <summary>
        /// Indicates whether DAB is running as an Azure Functions custom handler.
        /// </summary>
        public static bool IsRunningAsCustomHandler() => TryGetCustomHandlerPort(out _);

        /// <summary>
        /// Gets the URL Kestrel should bind to when running as a custom handler.
        /// The Functions host forwards requests over plain HTTP on the loopback interface;
        /// TLS is terminated by the Function App front end.
        /// </summary>
        /// <param name="url">The binding URL, e.g. http://localhost:12345.</param>
        /// <returns>True when a custom handler port was found.</returns>
        public static bool TryGetCustomHandlerUrl(out string url)
        {
            if (TryGetCustomHandlerPort(out int port))
            {
                url = $"http://localhost:{port}";
                return true;
            }

            url = string.Empty;
            return false;
        }
    }
}
