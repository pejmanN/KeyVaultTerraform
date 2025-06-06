﻿using Azure.Identity;
using KeyVaultTerraform.Settings;

namespace KeyVaultTerraform.Extensions
{
    public static class AzureKeyVaultExtension
    {
        public static WebApplicationBuilder ConfigureAzureKeyVault(this WebApplicationBuilder builder)
        {
            var keyVaultSettings = builder.Configuration.GetSection(nameof(KeyVaultSetting))
                                                        .Get<KeyVaultSetting>();
            if (!string.IsNullOrEmpty(keyVaultSettings?.Url))
            {
                builder.Configuration.AddAzureKeyVault(new Uri(keyVaultSettings.Url), new DefaultAzureCredential());
            }
            return builder;
        }
    }
}
